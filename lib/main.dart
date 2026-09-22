import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/cosmic_background.dart';
import 'data/models/user_model.dart';
import 'data/services/storage_service.dart';
import 'data/services/api_service.dart';
import 'features/auth/login_dialog.dart';
import 'features/hub/hub_screen.dart';
import 'features/cv_builder/cv_builder_screen.dart';

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
  String _currentRoute = 'hub'; // 'hub' or 'cv_builder'
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _isDark = widget.storage.isDarkTheme();
    _isCosmicActive = widget.storage.isCosmicActive();
    _currentUser = widget.storage.getCurrentUser();

    // No need to show modal over modal
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
          return CosmicBackground(
            isCosmicActive: _isCosmicActive,
            isDark: _isDark,
            child: _currentUser == null
                ? _buildLoggedOutView(ctx)
                : (_currentRoute == 'cv_builder'
                    ? CvBuilderScreen(
                        apiService: widget.apiService,
                        isDark: _isDark,
                        isCosmicActive: _isCosmicActive,
                        onBackToHub: () => setState(() => _currentRoute = 'hub'),
                        onLogout: _logout,
                        onToggleTheme: _toggleTheme,
                        onToggleCosmic: _toggleCosmic,
                      )
                    : HubScreen(
                        apiService: widget.apiService,
                        currentUser: _currentUser!,
                        isDark: _isDark,
                        isCosmicActive: _isCosmicActive,
                        onOpenCvBuilder: () => setState(() => _currentRoute = 'cv_builder'),
                        onLogout: _logout,
                        onToggleTheme: _toggleTheme,
                        onToggleCosmic: _toggleCosmic,
                      )),
          );
        },
      ),
    );
  }

  Widget _buildLoggedOutView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: LoginDialog(
          apiService: widget.apiService,
          onLoginSuccess: (user) {
            setState(() => _currentUser = user);
          },
        ),
      ),
    );
  }
}
