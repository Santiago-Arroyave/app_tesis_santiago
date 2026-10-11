import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:http/http.dart' as http;

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _identifierController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _success = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  static const Color _primaryGreen = Color(0xFF1E5E3A);
  static const Color _titleDarkGreen = Color(0xFF0F3A22);
  static const Color _inputFillColor = Color(0xF5FFFFFF);
  static const Color _inputLabelColor = Color(0xFF1B4332);

  @override
  void dispose() {
    _identifierController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/recover-password'),
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
        setState(() => _errorMessage = data['message'] ?? 'Error al recuperar contraseña');
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
                        "Recuperar contraseña",
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
                        "Ingresa tu correo y define una nueva contraseña",
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
                                    controller: _identifierController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2937)),
                                    decoration: InputDecoration(
                                      hintText: "Correo",
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
                                    validator: (v) => (v == null || v.trim().isEmpty) ? "Ingrese su correo" : null,
                                  ),
                                  const SizedBox(height: 7),

                                  TextFormField(
                                    controller: _newPasswordController,
                                    obscureText: _obscureNew,
                                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2937)),
                                    decoration: InputDecoration(
                                      hintText: "Nueva contraseña",
                                      filled: true,
                                      fillColor: _inputFillColor,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      prefixIcon: const Icon(Icons.lock_outline, color: _primaryGreen, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          color: const Color(0xFF6B7280),
                                          size: 18,
                                        ),
                                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                                      ),
                                      border: defaultInputBorder,
                                      enabledBorder: defaultInputBorder,
                                      focusedBorder: focusedInputBorder,
                                      errorBorder: errorInputBorder,
                                      focusedErrorBorder: focusedErrorInputBorder,
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? "Ingrese la nueva contraseña" : null,
                                  ),
                                  const SizedBox(height: 7),

                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirm,
                                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2937)),
                                    decoration: InputDecoration(
                                      hintText: "Confirmar nueva contraseña",
                                      filled: true,
                                      fillColor: _inputFillColor,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      prefixIcon: const Icon(Icons.lock_reset_outlined, color: _primaryGreen, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          color: const Color(0xFF6B7280),
                                          size: 18,
                                        ),
                                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                      ),
                                      border: defaultInputBorder,
                                      enabledBorder: defaultInputBorder,
                                      focusedBorder: focusedInputBorder,
                                      errorBorder: errorInputBorder,
                                      focusedErrorBorder: focusedErrorInputBorder,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return "Confirme su contraseña";
                                      if (v != _newPasswordController.text) return "Las contraseñas no coinciden";
                                      return null;
                                    },
                                  ),

                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],

                                  if (_success) ...[
                                    const SizedBox(height: 12),
                                    const Text(
                                      "¡Contraseña actualizada exitosamente!",
                                      style: TextStyle(color: Color(0xFF2E7D32), fontSize: 13, fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primaryGreen,
                                          foregroundColor: Colors.white,
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        child: const Text("VOLVER AL LOGIN", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],

                                  if (!_success) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _recover,
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
                                            : const Text("RECUPERAR", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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