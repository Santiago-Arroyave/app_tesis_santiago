import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goblink_park/screens/main_map/main_screen.dart';
import 'auth_service.dart';
import 'recover_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _canUseBiometrics = false;
  bool _rememberMe = false;

  static const Color _primaryGreen = Color(0xFF1E5E3A);
  static const Color _titleDarkGreen = Color(0xFF0F3A22);
  static const Color _inputFillColor = Color(0xF5FFFFFF);
  static const Color _inputLabelColor = Color(0xFF1B4332);

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;
      final savedEmail = prefs.getString('saved_login_email') ?? '';
      if (rememberMe && savedEmail.isNotEmpty) {
        if (mounted) {
          setState(() {
            _rememberMe = true;
            _correoController.text = savedEmail;
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando credenciales guardadas: $e');
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
      final token = await AuthService.getToken();
      if (biometricsEnabled && token != null && token.isNotEmpty) {
        if (mounted) {
          setState(() {
            _canUseBiometrics = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error verificando biometría en login: $e');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final LocalAuthentication auth = LocalAuthentication();
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Identifícate para ingresar a Goblin Park',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (didAuthenticate && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en autenticación biométrica: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    // Notificar al gestor de autocompletado nativo del sistema
    TextInput.finishAutofillContext();

    setState(() => _isLoading = true);

    final email = _correoController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    final result = await AuthService.login(
      correo: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('saved_login_email', email);
        } else {
          await prefs.setBool('remember_me', false);
          await prefs.remove('saved_login_email');
        }
      } catch (e) {
        debugPrint('Error persistiendo credenciales: $e');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.8),
    );

    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
    );

    final errorInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.0),
    );

    final focusedErrorInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo
          Positioned.fill(
            child: Image.asset(
              'assets/images/Fondo-Login.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // Contenido
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 10.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Logo
                      Center(
                        child: Image.asset(
                          'assets/images/Logo verde.png',
                          height: 115,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Título
                      const Text(
                        "Iniciar Sesión",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _titleDarkGreen,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Subtítulo
                      const Text(
                        "Plataforma de monitoreo ambiental \nPNR Páramo del Duende",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: _inputLabelColor,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tarjeta de glassmorphism
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                            decoration: BoxDecoration(
                              color: const Color(0x4DFFFFFF),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1.0,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: AutofillGroup(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Campo Correo
                                    TextFormField(
                                      controller: _correoController,
                                      autofillHints: const [
                                        AutofillHints.email,
                                        AutofillHints.username,
                                      ],
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (_) => setState(() => _errorMessage = null),
                                      style: const TextStyle(
                                        color: Color(0xFF1F2937),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Correo / Nickname",
                                        hintStyle: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 13,
                                        ),
                                        filled: true,
                                        fillColor: _inputFillColor,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 11,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: _primaryGreen,
                                          size: 21,
                                        ),
                                        border: defaultInputBorder,
                                        enabledBorder: defaultInputBorder,
                                        focusedBorder: focusedInputBorder,
                                        errorBorder: errorInputBorder,
                                        focusedErrorBorder: focusedErrorInputBorder,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return "Ingrese su correo";
                                        if (!v.contains('@')) return "Correo inválido";
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 10),

                                    // Campo Contraseña
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      autofillHints: const [AutofillHints.password],
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _login(),
                                      onChanged: (_) => setState(() => _errorMessage = null),
                                      style: const TextStyle(
                                        color: Color(0xFF1F2937),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Contraseña",
                                        hintStyle: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 13,
                                        ),
                                        filled: true,
                                        fillColor: _inputFillColor,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 11,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                          color: _primaryGreen,
                                          size: 21,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: const Color(0xFF6B7280),
                                            size: 19,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                        border: defaultInputBorder,
                                        enabledBorder: defaultInputBorder,
                                        focusedBorder: focusedInputBorder,
                                        errorBorder: errorInputBorder,
                                        focusedErrorBorder: focusedErrorInputBorder,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return "Ingrese su contraseña";
                                        return null;
                                      },
                                    ),

                                    // Mensaje de error
                                    if (_errorMessage != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFFCA5A5)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: const TextStyle(
                                                  color: Color(0xFFB91C1C),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 4),

                                    // Fila Recordar usuario y Recuperar contraseña
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _rememberMe = !_rememberMe;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: Checkbox(
                                                    value: _rememberMe,
                                                    activeColor: _primaryGreen,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    side: const BorderSide(
                                                      color: _primaryGreen,
                                                      width: 1.5,
                                                    ),
                                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    onChanged: (val) {
                                                      setState(() {
                                                        _rememberMe = val ?? false;
                                                      });
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  "Recordar usuario",
                                                  style: TextStyle(
                                                    color: _titleDarkGreen,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const RecoverPasswordScreen()),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            foregroundColor: _titleDarkGreen,
                                          ),
                                          child: const Text(
                                            "Recuperar contraseña?",
                                            style: TextStyle(
                                              color: _titleDarkGreen,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Botón LOGIN y Botón Biometría
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 45,
                                            child: ElevatedButton(
                                              onPressed: _isLoading ? null : _login,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _primaryGreen,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor: const Color(0xB31E5E3A),
                                                elevation: 1.5,
                                                shadowColor: const Color(0x331E5E3A),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                              ),
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                                    )
                                                  : const Text(
                                                      "LOGIN",
                                                      style: TextStyle(
                                                        fontSize: 14.5,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        if (_canUseBiometrics) ...[
                                          const SizedBox(width: 10),
                                          Material(
                                            color: Colors.transparent,
                                            child: Ink(
                                              width: 45,
                                              height: 45,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0xFF1E5E3A), width: 1.5),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x1A000000),
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: InkWell(
                                                onTap: _authenticateWithBiometrics,
                                                borderRadius: BorderRadius.circular(25),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.fingerprint,
                                                    color: Color(0xFF1E5E3A),
                                                    size: 28,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Footer
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          "¿No tienes cuenta? ",
                                          style: TextStyle(fontSize: 12.5, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                          ),
                                          child: const Text(
                                            "Regístrate",
                                            style: TextStyle(color: _titleDarkGreen, fontWeight: FontWeight.bold, fontSize: 12.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}