//import 'package:app_tesis/main.dart';
//import 'package:app_tesis/screens/main_home.dart';
//import 'package:flutter/material.dart';
//import 'package:app_tesis/screens/main_map/home_map_screen.dart';
//import 'package:app_tesis/screens/main_map/main_screen.dart';
//import '../main.dart'; // o tu pantalla principal

import 'package:flutter/material.dart';
import 'package:app_tesis/screens/main_map/main_screen.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  String? _errorMessage;

  Future<void> _login() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await AuthService.login(
      correo: _correoController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Image.asset('assets/images/Logo verde.png',
                        width: 110),
                  ),
                  const SizedBox(height: 20),
                  const Text("Iniciar sesión",
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 30),

                  // ── Correo ────────────────────────────────────
                  TextFormField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() => _errorMessage = null),
                    decoration: InputDecoration(
                      hintText: "Correo",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return "Ingrese su correo";
                      if (!v.contains('@')) return "Correo inválido";
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // ── Contraseña ────────────────────────────────
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: (_) => setState(() => _errorMessage = null),
                    decoration: InputDecoration(
                      hintText: "Contraseña",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "Ingrese su contraseña" : null,
                  ),

                  // ── Error ─────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_rounded,
                              color: Colors.red.shade600, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Recuperar contraseña ──────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const RecoverPasswordScreen()),
                      ),
                      child: const Text("Recuperar contraseña?",
                          style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Botón LOGIN ───────────────────────────────
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text("LOGIN",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
                          ),
                        ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("¿No tienes cuenta? "),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        child: const Text("Sign Up",
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Image.asset('assets/images/plantas.png',
                      width: double.infinity, fit: BoxFit.cover),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Recuperar Contraseña ────────────────────────────────────────────────────

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() =>
      _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _identifierController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _success = false;

  Future<void> _recover() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/auth/recover-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': _identifierController.text.trim(),
          'newPassword': _newPasswordController.text.trim(),
          'confirmNewPassword': _confirmPasswordController.text.trim(),
        }),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        setState(() => _success = true);
      } else {
        final data = jsonDecode(response.body);
        setState(() =>
            _errorMessage = data['message'] ?? 'Error al recuperar contraseña');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error de conexión: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Image.asset('assets/images/Logo verde.png',
                        width: 110),
                  ),
                  const SizedBox(height: 20),
                  const Text("Recuperar contraseña",
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 30),

                  // ── Correo o identificador ────────────────
                  TextFormField(
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: "Correo",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "Ingrese su correo" : null,
                  ),
                  const SizedBox(height: 15),

                  // ── Nueva contraseña ──────────────────────
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Nueva contraseña",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "Ingrese la nueva contraseña" : null,
                  ),
                  const SizedBox(height: 15),

                  // ── Confirmar contraseña ──────────────────
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Confirmar nueva contraseña",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return "Confirme su contraseña";
                      if (v != _newPasswordController.text)
                        return "Las contraseñas no coinciden";
                      return null;
                    },
                  ),

                  // ── Error ─────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_rounded,
                              color: Colors.red.shade600, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Éxito ─────────────────────────────────
                  if (_success) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600, size: 32),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Contraseña actualizada exitosamente',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Volver al login',
                            style: TextStyle(
                                fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],

                  if (!_success) ...[
                    const SizedBox(height: 16),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _recover,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text("RECUPERAR",
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white)),
                            ),
                          ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("¿Ya tienes una cuenta? "),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text("Login",
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 30),
                  Image.asset('assets/images/plantas.png',
                      width: double.infinity, fit: BoxFit.cover),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/*class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _success = false;

  Future<void> _recover() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // TODO: conectar con endpoint de recuperación cuando esté disponible
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _success = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Image.asset('assets/images/Logo verde.png',
                        width: 110),
                  ),
                  const SizedBox(height: 20),
                  const Text("Recuperar contraseña",
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 30),

                  TextFormField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: "Correo",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "Ingrese su correo" : null,
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Nueva contraseña",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "Ingrese la nueva contraseña" : null,
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_rounded,
                              color: Colors.red.shade600, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_success) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600, size: 32),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Contraseña actualizada',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _recover,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text("RECUPERAR",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
                          ),
                        ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("¿Ya tienes una cuenta? "),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text("Login",
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Image.asset('assets/images/plantas.png',
                      width: double.infinity, fit: BoxFit.cover),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}*/

// ─── Registro ────────────────────────────────────────────────────────────────

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

  void _requestPermissions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PermissionDialog(
        icon: Icons.location_on,
        iconColor: Colors.green.shade700,
        appName: 'GoblinPark',
        message: 'acceda a la ubicación de este dispositivo?',
        onReject: () {
          Navigator.pop(ctx);
          _goToMain();
        },
        onAllow: () {
          Navigator.pop(ctx);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx2) => _PermissionDialog(
              icon: Icons.camera_alt,
              iconColor: Colors.green.shade700,
              appName: 'GoblinPark',
              message: 'tome fotos?',
              onReject: () {
                Navigator.pop(ctx2);
                _goToMain();
              },
              onAllow: () {
                Navigator.pop(ctx2);
                _goToMain();
              },
            ),
          );
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Image.asset('assets/images/Logo verde.png',
                        width: 110),
                  ),
                  const SizedBox(height: 20),
                  const Text("Registrarse",
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 30),

                  // ── Nombres ───────────────────────────────────
                  TextFormField(
                    controller: _nombresController,
                    decoration: InputDecoration(
                      hintText: "Nombre",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "Ingrese su nombre" : null,
                  ),
                  const SizedBox(height: 15),

                  // ── Correo ────────────────────────────────────
                  TextFormField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: "Correo",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return "Ingrese su correo";
                      if (!v.contains('@')) return "Correo inválido";
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // ── Contraseña ────────────────────────────────
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Contraseña",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "Ingrese una contraseña" : null,
                  ),
                  const SizedBox(height: 15),

                  // ── Confirmar contraseña ──────────────────────
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Confirmar contraseña",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return "Confirme su contraseña";
                      if (v != _passwordController.text)
                        return "Las contraseñas no coinciden";
                      return null;
                    },
                  ),

                  // ── Error ─────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_rounded,
                              color: Colors.red.shade600, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text("SIGN UP",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
                          ),
                        ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("¿Ya tienes una cuenta? "),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text("Login",
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Image.asset('assets/images/plantas.png',
                      width: double.infinity, fit: BoxFit.cover),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Diálogo de Permiso ──────────────────────────────────────────────────────

class _PermissionDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String appName;
  final String message;
  final VoidCallback onReject;
  final VoidCallback onAllow;

  const _PermissionDialog({
    required this.icon,
    required this.iconColor,
    required this.appName,
    required this.message,
    required this.onReject,
    required this.onAllow,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 40),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style:
                  const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                const TextSpan(text: '¿Permitir que '),
                TextSpan(
                  text: appName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' $message'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onReject,
          child: const Text('Rechazar',
              style: TextStyle(color: Colors.black54)),
        ),
        ElevatedButton(
          onPressed: onAllow,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              foregroundColor: Colors.white),
          child: const Text('Permitir'),
        ),
      ],
    );
  }
}

/*
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  void login() {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      Future.delayed(const Duration(seconds: 2), () {
        setState(() => isLoading = false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavigation(), // tu pantalla principal
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // 🔥 LOGO CENTRADO (igual que quieres)
                  Center(
                    child: Image.asset(
                      'assets/images/Logo verde.png',
                      width: 110,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TEXTO (alineado a la izquierda como en la imagen)
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      "Iniciar sesión",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // INPUT USUARIO
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: "Nickname",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? "Ingrese su usuario" : null,
                  ),

                  const SizedBox(height: 15),

                  // INPUT PASSWORD
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Contraseña",
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? "Ingrese su contraseña" : null,
                  ),

                  const SizedBox(height: 10),

                  // RECUPERAR CONTRASEÑA
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        "Recuperar contraseña?",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // BOTÓN LOGIN
                  isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "LOGIN",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                  const SizedBox(height: 20),

                  // SIGN UP
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("¿No tienes cuenta? "),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  Image.asset(
                    'assets/images/plantas.png',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  //const Icon(Icons.work, size: 80, color: Colors.green),
                  Image.asset(
                    'assets/images/Logo verde.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 10),

                  const SizedBox(height: 10),

                  const Text(
                    "Iniciar Sesión",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 30),

                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: "Correo",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? "Ingrese su correo" : null,
                  ),

                  const SizedBox(height: 15),

                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Contraseña",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? "Ingrese su contraseña" : null,
                  ),

                  const SizedBox(height: 20),

                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: login,
                          child: const Text("Ingresar"),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }*/
//}
