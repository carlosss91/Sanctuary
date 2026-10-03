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
  bool _isForgotPassword = false;
  int _recoveryStep = 1; // 1: request token, 2: input token and new password

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Forgot password controllers
  final _recoveryEmailController = TextEditingController();
  final _resetTokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _confirmPasswordController.dispose();
    _recoveryEmailController.dispose();
    _resetTokenController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Completa todos los campos requeridos');
      return;
    }

    if (_isRegister) {
      if (email.isEmpty || !email.contains('@')) {
        setState(() => _errorMessage = 'Introduce un correo electrónico válido para la activación');
        return;
      }
      if (password.length < 6) {
        setState(() => _errorMessage = 'La contraseña debe tener al menos 6 caracteres');
        return;
      }
      if (password != confirmPassword) {
        setState(() => _errorMessage = 'Las contraseñas no coinciden');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (_isRegister) {
        final res = await widget.apiService.register(
          username,
          password,
          email: email,
          confirmPassword: confirmPassword,
          role: 'usuario',
        );
        if (res['success'] == true) {
          final user = res['user'] as UserModel?;
          if (user != null) {
            widget.onLoginSuccess(user);
            if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
          } else {
            setState(() {
              _isRegister = false;
              _successMessage = res['message'] ?? 'Registro completado. Revisa tu correo para activar la cuenta.';
            });
          }
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

  Future<void> _submitForgotPasswordStep1() async {
    final email = _recoveryEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Introduce un correo electrónico válido');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final res = await widget.apiService.forgotPassword(email);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _recoveryStep = 2;
          _successMessage = res['message'] ?? 'Código de restablecimiento enviado a tu correo.';
          if (res['preview_token'] != null) {
            _resetTokenController.text = res['preview_token'].toString();
          }
        } else {
          _errorMessage = res['message'] ?? 'Error al solicitar recuperación';
        }
      });
    }
  }

  Future<void> _submitForgotPasswordStep2() async {
    final email = _recoveryEmailController.text.trim();
    final token = _resetTokenController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmNewPassword = _confirmNewPasswordController.text.trim();

    if (token.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty) {
      setState(() => _errorMessage = 'Completa todos los campos');
      return;
    }

    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (newPassword != confirmNewPassword) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final res = await widget.apiService.resetPassword(
      email: email,
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmNewPassword,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _isForgotPassword = false;
          _recoveryStep = 1;
          _passwordController.text = newPassword;
          _successMessage = '¡Contraseña actualizada! Ya puedes iniciar sesión.';
        } else {
          _errorMessage = res['message'] ?? 'Error al cambiar contraseña';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C1322).withOpacity(0.96) : Colors.white.withOpacity(0.98),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withOpacity(0.18),
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
                                color: const Color(0xFF06B6D4).withOpacity(0.35),
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

                  // Subtitle
                  Text(
                    _isForgotPassword
                        ? 'Recuperación de Contraseña'
                        : (_isRegister ? 'Crear Nueva Cuenta' : 'Iniciar Sesión'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),

                  if (_successMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.emerald.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(color: AppTheme.emerald, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ==========================================
                  // FORGOT PASSWORD VIEW
                  // ==========================================
                  if (_isForgotPassword) ...[
                    if (_recoveryStep == 1) ...[
                      const Text('Correo Electrónico de la Cuenta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _recoveryEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.mail_outline, size: 19),
                          hintText: 'tu.correo@ejemplo.com',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onSubmitted: (_) => _submitForgotPasswordStep1(),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitForgotPasswordStep1,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Enviar Enlace de Recuperación', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      const Text('Código / Token de Restablecimiento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _resetTokenController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.vpn_key_outlined, size: 19),
                          hintText: 'Token recibido por correo',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Nueva Contraseña (mínimo 6 caracteres)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline, size: 19),
                          hintText: '••••••••',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Confirmar Nueva Contraseña', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _confirmNewPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_reset, size: 19),
                          hintText: '••••••••',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onSubmitted: (_) => _submitForgotPasswordStep2(),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitForgotPasswordStep2,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Guardar Nueva Contraseña', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isForgotPassword = false;
                          _recoveryStep = 1;
                          _errorMessage = null;
                        });
                      },
                      child: const Text('← Volver a Iniciar Sesión', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
                    ),
                  ]

                  // ==========================================
                  // REGULAR LOGIN / REGISTER VIEW
                  // ==========================================
                  else ...[
                    // Username field
                    const Text('Usuario', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline, size: 19),
                        hintText: 'Nombre de usuario',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    if (_isRegister) ...[
                      const SizedBox(height: 14),
                      const Text('Correo Electrónico (para activación)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.mail_outline, size: 19),
                          hintText: 'ejemplo@correo.com',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],

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
                      onSubmitted: (_) {
                        if (!_isRegister) _submit();
                      },
                    ),

                    // Confirm Password field for Registration
                    if (_isRegister) ...[
                      const SizedBox(height: 14),
                      const Text('Repetir Contraseña *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_reset, size: 19),
                          hintText: '••••••••',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.25)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.mark_email_read_outlined, size: 18, color: Color(0xFF06B6D4)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'La contraseña se almacena encriptada (bcrypt). Recibirás un enlace por correo electrónico para verificar tu cuenta.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF06B6D4), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isForgotPassword = true;
                              _recoveryStep = 1;
                              _recoveryEmailController.text = _emailController.text;
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Submit button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
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
                          : Text(_isRegister ? 'Crear Cuenta y Activar' : 'Entrar al Santuario'),
                    ),

                    const SizedBox(height: 14),

                    // Switch between Login and Register
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isRegister = !_isRegister;
                          _isForgotPassword = false;
                          _errorMessage = null;
                          _successMessage = null;
                        });
                      },
                      child: Text(
                        _isRegister
                            ? '¿Ya tienes cuenta? Iniciar Sesión'
                            : '¿No tienes cuenta? Crear nuevo usuario',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF06B6D4), fontWeight: FontWeight.w600),
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
