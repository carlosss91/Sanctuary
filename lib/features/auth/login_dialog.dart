import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';
import '../../data/models/user_model.dart';

class LoginDialog extends StatefulWidget {
  final ApiService apiService;
  final ValueChanged<UserModel> onLoginSuccess;

  const LoginDialog({
    super.key,
    required this.apiService,
    required this.onLoginSuccess,
  });

  static Future<void> show(BuildContext context, ApiService api, ValueChanged<UserModel> onSuccess) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => LoginDialog(apiService: api, onLoginSuccess: onSuccess),
    );
  }

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  bool _isRegister = false;
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin');
  final _roleController = TextEditingController(text: 'admin');
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Completa todos los campos requeridos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegister) {
        final res = await widget.apiService.register(
          username,
          password,
          role: _roleController.text.trim().isEmpty ? 'usuario' : _roleController.text.trim(),
        );
        if (res['success'] == true) {
          final user = res['user'] as UserModel;
          widget.onLoginSuccess(user);
          if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
        } else {
          setState(() => _errorMessage = res['message'] ?? 'Error al registrar usuario');
        }
      } else {
        final res = await widget.apiService.login(username, password);
        if (res['success'] == true) {
          final user = res['user'] as UserModel;
          widget.onLoginSuccess(user);
          if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
        } else {
          setState(() => _errorMessage = res['message'] ?? 'Credenciales incorrectas');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error de conexión con el servidor: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C1322).withOpacity(0.94) : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.emerald.withOpacity(0.18),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 34),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==========================================
                  // CELESTIAL UNIVERSE LOGO & BRANDING
                  // ==========================================
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ambient radial glow behind planet
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.emerald.withOpacity(0.35),
                                blurRadius: 26,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        // Universe Planet with Ring
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CustomPaint(
                            painter: UniverseLogoPainter(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title: "SANCTUARY"
                  const Text(
                    'SANCTUARY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.5,
                      fontFamily: 'Inter',
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Subtitle: Iniciar Sesión (in the upper part of the modal)
                  Text(
                    _isRegister ? 'Crear Nueva Cuenta' : 'Iniciar Sesión',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Quick Access notice for convenience
                  if (!_isRegister)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.emerald.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppTheme.emerald, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Acceso rápido predeterminado: admin / admin',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF6EE7B7) : AppTheme.emerald,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.35)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Username field
                  const Text('Usuario', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline, size: 19),
                      hintText: 'admin',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Password field
                  const Text('Contraseña', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, size: 19),
                      hintText: '••••••••',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),

                  if (_isRegister) ...[
                    const SizedBox(height: 14),
                    const Text('Rol / Especialidad', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _roleController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined, size: 19),
                        hintText: 'admin / docente / alumno',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(_isRegister ? 'Crear Cuenta' : 'Entrar al Santuario'),
                  ),

                  const SizedBox(height: 14),

                  // Switch between Login and Register
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isRegister = !_isRegister;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isRegister
                          ? '¿Ya tienes cuenta? Iniciar Sesión'
                          : '¿No tienes cuenta? Crear nuevo usuario',
                      style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// CUSTOM UNIVERSE LOGO PAINTER (Planeta anillado + Nebulosa orbital + Destello)
// ==============================================================================
class UniverseLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double planetR = 24.0;

    // 1. Orbital ring behind planet (back half)
    final ringPaint = Paint()
      ..color = const Color(0xFF34D399).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.42);

    // Draw full back ellipse
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: planetR * 3.4, height: planetR * 1.05),
      math.pi,
      math.pi,
      false,
      ringPaint,
    );
    canvas.restore();

    // 2. Planet Sphere with 3D Radiant Gradient
    final planetPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        colors: [
          Color(0xFF6EE7B7),
          Color(0xFF10B981),
          Color(0xFF047857),
          Color(0xFF022C22),
        ],
        stops: [0.0, 0.45, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: planetR));

    canvas.drawCircle(center, planetR, planetPaint);

    // 3. Orbital ring in front of planet (front half)
    final frontRingPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF6EE7B7),
          Color(0xFF38BDF8),
          Color(0xFF10B981),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: planetR * 1.8))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.42);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: planetR * 3.4, height: planetR * 1.05),
      0,
      math.pi,
      false,
      frontRingPaint,
    );
    canvas.restore();

    // 4. Sparkling star on the planet's crest
    final sparkCenter = Offset(center.dx + 12, center.dy - 12);
    final sparkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(sparkCenter.dx - 5, sparkCenter.dy), Offset(sparkCenter.dx + 5, sparkCenter.dy), sparkPaint);
    canvas.drawLine(Offset(sparkCenter.dx, sparkCenter.dy - 5), Offset(sparkCenter.dx, sparkCenter.dy + 5), sparkPaint);
    canvas.drawCircle(sparkCenter, 1.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
