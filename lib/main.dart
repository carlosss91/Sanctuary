import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/cosmic_background.dart';
import 'data/models/user_model.dart';
import 'data/services/storage_service.dart';
import 'data/services/api_service.dart';
import 'features/auth/login_dialog.dart';
import 'features/hub/hub_screen.dart';
import 'features/cv_builder/cv_builder_screen.dart';
import 'features/pdf_signer/pdf_signer_screen.dart';
import 'features/prezi2pdf/prezi_to_pdf_screen.dart';
import 'features/admin/admin_panel_screen.dart';
import 'features/chat/chat_floating_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();
  final api = ApiService(storage: storage);

  runApp(SanctuaryApp(storage: storage, apiService: api));
}

class SanctuaryApp extends StatefulWidget {
  final StorageService storage;
  final ApiService apiService;

  const SanctuaryApp({
    super.key,
    required this.storage,
    required this.apiService,
  });

  @override
  State<SanctuaryApp> createState() => _SanctuaryAppState();
}

class _SanctuaryAppState extends State<SanctuaryApp> {
  late bool _isDark;
  late bool _isCosmicActive;
  UserModel? _currentUser;
  String _currentRoute = 'hub'; // 'hub', 'cv_builder', 'pdf_signer', 'prezi2pdf', or 'admin_panel'
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _isDark = widget.storage.isDarkTheme();
    _isCosmicActive = widget.storage.isCosmicActive();
    _currentUser = widget.storage.getCurrentUser();
  }

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
      widget.storage.setThemeMode(_isDark);
    });
  }

  void _toggleCosmic() {
    setState(() {
      _isCosmicActive = !_isCosmicActive;
      widget.storage.setCosmicActive(_isCosmicActive);
    });
  }

  void _logout() async {
    await widget.storage.setCurrentUser(null);
    setState(() {
      _currentUser = null;
      _currentRoute = 'hub';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Sanctuary · Web Apps & CV Builder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (ctx) {
          Widget currentScreen;
          if (_currentUser == null) {
            currentScreen = _buildLoggedOutView(ctx);
          } else if (_currentRoute == 'admin_panel' && _currentUser!.role.toLowerCase() == 'admin') {
            currentScreen = AdminPanelScreen(
              apiService: widget.apiService,
              currentUser: _currentUser!,
              isDark: _isDark,
              isCosmicActive: _isCosmicActive,
              onBackToHub: () => setState(() => _currentRoute = 'hub'),
              onOpenCvBuilder: () => setState(() => _currentRoute = 'cv_builder'),
              onOpenPdfSigner: () => setState(() => _currentRoute = 'pdf_signer'),
              onOpenPreziDownloader: () => setState(() => _currentRoute = 'prezi2pdf'),
              onLogout: _logout,
              onToggleTheme: _toggleTheme,
              onToggleCosmic: _toggleCosmic,
            );
          } else if (_currentRoute == 'cv_builder') {
            currentScreen = CvBuilderScreen(
              apiService: widget.apiService,
              isDark: _isDark,
              isCosmicActive: _isCosmicActive,
              onBackToHub: () => setState(() => _currentRoute = 'hub'),
              onOpenPdfSigner: () => setState(() => _currentRoute = 'pdf_signer'),
              onOpenPreziDownloader: () => setState(() => _currentRoute = 'prezi2pdf'),
              onOpenAdminPanel: () => setState(() => _currentRoute = 'admin_panel'),
              onLogout: _logout,
              onToggleTheme: _toggleTheme,
              onToggleCosmic: _toggleCosmic,
            );
          } else if (_currentRoute == 'pdf_signer') {
            currentScreen = PdfSignerScreen(
              apiService: widget.apiService,
              isDark: _isDark,
              isCosmicActive: _isCosmicActive,
              onBackToHub: () => setState(() => _currentRoute = 'hub'),
              onOpenCvBuilder: () => setState(() => _currentRoute = 'cv_builder'),
              onOpenPreziDownloader: () => setState(() => _currentRoute = 'prezi2pdf'),
              onOpenAdminPanel: () => setState(() => _currentRoute = 'admin_panel'),
              onLogout: _logout,
              onToggleTheme: _toggleTheme,
              onToggleCosmic: _toggleCosmic,
            );
          } else if (_currentRoute == 'prezi2pdf') {
            currentScreen = PreziToPdfScreen(
              apiService: widget.apiService,
              isDark: _isDark,
              isCosmicActive: _isCosmicActive,
              onBackToHub: () => setState(() => _currentRoute = 'hub'),
              onOpenCvBuilder: () => setState(() => _currentRoute = 'cv_builder'),
              onOpenPdfSigner: () => setState(() => _currentRoute = 'pdf_signer'),
              onOpenAdminPanel: () => setState(() => _currentRoute = 'admin_panel'),
              onLogout: _logout,
              onToggleTheme: _toggleTheme,
              onToggleCosmic: _toggleCosmic,
            );
          } else {
            currentScreen = HubScreen(
              apiService: widget.apiService,
              currentUser: _currentUser!,
              isDark: _isDark,
              isCosmicActive: _isCosmicActive,
              onOpenCvBuilder: () => setState(() => _currentRoute = 'cv_builder'),
              onOpenPdfSigner: () => setState(() => _currentRoute = 'pdf_signer'),
              onOpenPreziDownloader: () => setState(() => _currentRoute = 'prezi2pdf'),
              onOpenAdminPanel: () => setState(() => _currentRoute = 'admin_panel'),
              onLogout: _logout,
              onToggleTheme: _toggleTheme,
              onToggleCosmic: _toggleCosmic,
            );
          }

          return CosmicBackground(
            isCosmicActive: _isCosmicActive,
            isDark: _isDark,
            child: Stack(
              children: [
                currentScreen,
                if (_currentUser != null) ...[
                  // Ephemeral Community Chat Floating Widget
                  Positioned(
                    right: 22,
                    bottom: 22,
                    child: SanctuaryChatWidget(
                      apiService: widget.apiService,
                      currentUser: _currentUser!,
                      isDark: _isDark,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoggedOutView(BuildContext context) {
    final isDark = _isDark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Central Login Card
          Center(
            child: LoginDialog(
              apiService: widget.apiService,
              onLoginSuccess: (user) {
                setState(() => _currentUser = user);
              },
            ),
          ),

          // Top floating controls for Theme & Cosmic Animations
          Positioned(
            top: 24,
            right: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155).withOpacity(0.7) : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cosmic animation toggle
                  IconButton(
                    tooltip: _isCosmicActive ? 'Pausar animación cósmica' : 'Activar animación cósmica',
                    icon: Icon(
                      _isCosmicActive ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                      color: _isCosmicActive ? AppTheme.emerald : (isDark ? Colors.grey : Colors.blueGrey),
                      size: 20,
                    ),
                    onPressed: _toggleCosmic,
                  ),
                  const SizedBox(width: 4),
                  // Theme toggle
                  IconButton(
                    tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                    icon: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: isDark ? Colors.amberAccent : const Color(0xFF1E293B),
                      size: 20,
                    ),
                    onPressed: _toggleTheme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
