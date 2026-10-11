import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:goblink_park/screens/main_map/main_screen.dart';
import 'auth_service.dart';
import 'permission_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombresController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  static const Color _primaryGreen = Color(0xFF1E5E3A);
  static const Color _titleDarkGreen = Color(0xFF0F3A22);
  static const Color _inputFillColor = Color(0xF5FFFFFF);
  static const Color _inputLabelColor = Color(0xFF1B4332);

  @override
  void dispose() {
    _nombresController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await AuthService.register(
      nombres: _nombresController.text.trim(),
      correo: _correoController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _requestPermissions();
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _goToMain();
      return;
    }

    _requestCameraPermission();
  }

  void _requestPermissions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x73000000),
      builder: (ctx) => PermissionDialog(
        icon: Icons.location_on,
        titleAppName: 'Monitoreo Duende',
        description: 'acceda a la ubicación de este dispositivo para georreferenciar los reportes de flora y avistamientos en tiempo real?',
        onReject: () {
          Navigator.pop(ctx);
          _goToMain();
        },
        onAllow: () async {
          Navigator.pop(ctx);
          await _requestLocationPermission();
        },
      ),
    );
  }

  void _requestCameraPermission() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x73000000),
      builder: (ctx) => PermissionDialog(
        icon: Icons.camera_alt_rounded,
        titleAppName: 'Monitoreo Duende',
        description: 'acceda a la cámara para tomar fotografías y evidencias de los especímenes durante los recorridos?',
        onReject: () {
          Navigator.pop(ctx);
          _goToMain();
        },
        onAllow: () {
          Navigator.pop(ctx);
          _goToMain();
        },
      ),
    );
  }

  void _goToMain() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.8),
    );

    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
    );

    final errorInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.0),
    );

    final focusedErrorInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Fondo-Login.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),

                      Image.asset(
                        'assets/images/Logo verde.png',
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "Crear Cuenta",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _titleDarkGreen,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),

                      const Text(
                        "Plataforma de monitoreo ambiental\nPNR Páramo del Duende",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: _inputLabelColor,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 20),

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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _nombresController,
                                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2937)),
                                    decoration: InputDecoration(
                                      hintText: "Nombre completo",
                                      filled: true,
                                      fillColor: _inputFillColor,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      prefixIcon: const Icon(Icons.person_outline, color: _primaryGreen, size: 20),
                                      border: defaultInputBorder,
                                      enabledBorder: defaultInputBorder,
                                      focusedBorder: focusedInputBorder,
                                      errorBorder: errorInputBorder,
                                      focusedErrorBorder: focusedErrorInputBorder,
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? "Ingrese su nombre" : null,
                                  ),
                                  const SizedBox(height: 7),

                                  TextFormField(
                                    controller: _correoController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2937)),
                                    decoration: InputDecoration(
                                      hintText: "Correo electrónico",
                                      filled: true,
                                      fillColor: _inputFillColor,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      prefixIcon: const Icon(Icons.email_outlined, color: _primaryGreen, size: 20),
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
                                  const SizedBox(height: 7),

                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2937)),
                                    decoration: InputDecoration(
                                      hintText: "Contraseña",
                                      filled: true,
                                      fillColor: _inputFillColor,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      prefixIcon: const Icon(Icons.lock_outline, color: _primaryGreen, size: 20),
                                      border: defaultInputBorder,
                                      enabledBorder: defaultInputBorder,
                                      focusedBorder: focusedInputBorder,
                                      errorBorder: errorInputBorder,
                                      focusedErrorBorder: focusedErrorInputBorder,
                                    ),
                                    validator: (v) => (v == null || v.length < 6) ? "Mínimo 6 caracteres" : null,
                                  ),
                                  const SizedBox(height: 7),

                                  TextFormField(
                                    controller: _confirmController,
                                    obscureText: true,
                                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2937)),
                                    decoration: InputDecoration(
                                      hintText: "Confirmar contraseña",
                                      filled: true,
                                      fillColor: _inputFillColor,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      prefixIcon: const Icon(Icons.lock_reset_outlined, color: _primaryGreen, size: 20),
                                      border: defaultInputBorder,
                                      enabledBorder: defaultInputBorder,
                                      focusedBorder: focusedInputBorder,
                                      errorBorder: errorInputBorder,
                                      focusedErrorBorder: focusedErrorInputBorder,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return "Confirme su contraseña";
                                      if (v != _passwordController.text) return "Las contraseñas no coinciden";
                                      return null;
                                    },
                                  ),

                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],

                                  const SizedBox(height: 10),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _register,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryGreen,
                                        foregroundColor: Colors.white,
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : const Text("REGISTRARSE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "¿Ya tienes una cuenta? ",
                                        style: TextStyle(fontSize: 12, color: Color(0xFF374151)),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: const Text(
                                          "Login",
                                          style: TextStyle(color: _titleDarkGreen, fontWeight: FontWeight.bold, fontSize: 12),
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