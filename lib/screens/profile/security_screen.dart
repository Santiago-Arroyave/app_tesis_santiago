import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/profile/notifications_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _biometricEnabled = false;
  bool _isUpdating = false;
  bool _showSuccessBanner = false;

  String _newPassword = '';

  @override
  void initState() {
    super.initState();
    _loadBiometricPreference();
    _newPasswordController.addListener(() {
      setState(() {
        _newPassword = _newPasswordController.text;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('biometrics_enabled') ?? false;
    if (mounted) {
      setState(() {
        _biometricEnabled = value;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      try {
        final LocalAuthentication auth = LocalAuthentication();
        final bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
        if (canCheck) {
          await prefs.setBool('biometrics_enabled', true);
          if (!mounted) return;
          setState(() {
            _biometricEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Autenticación biométrica habilitada para este dispositivo."),
              backgroundColor: Color(0xFF1E5E3A),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          await prefs.setBool('biometrics_enabled', false);
          if (!mounted) return;
          setState(() {
            _biometricEnabled = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("El dispositivo no tiene biometría configurada o no es compatible."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        await prefs.setBool('biometrics_enabled', false);
        if (!mounted) return;
        setState(() {
          _biometricEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al verificar biometría: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      await prefs.setBool('biometrics_enabled', false);
      if (!mounted) return;
      setState(() {
        _biometricEnabled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Autenticación biométrica desactivada."),
          backgroundColor: Color(0xFF1E5E3A),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _scrollToPasswordForm() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _showActiveSessionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_android_rounded, color: Color(0xFF1E5E3A), size: 24),
            SizedBox(width: 10),
            Text(
              "Sesión activa",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3A22),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Estás utilizando la aplicación en este dispositivo móvil con autenticación segura.",
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.35),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Dispositivo:", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      Text("Terminal móvil Android/iOS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Estado:", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      Text("Conectado (Activo)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Área:", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      Text("PNR Páramo del Duende", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E5E3A))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar", style: TextStyle(color: Color(0xFF1E5E3A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final hasMinLength = _newPassword.length >= 8;
    final hasLetterAndNumber = RegExp(r'(?=.*[a-zA-Z])(?=.*[0-9])').hasMatch(_newPassword);
    final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(_newPassword);

    if (!hasMinLength || !hasLetterAndNumber || !hasSpecialChar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La nueva contraseña no cumple con todos los requisitos de seguridad."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Las contraseñas no coinciden."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se encontró una sesión activa. Inicia sesión nuevamente."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/change-password');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': _currentPasswordController.text.trim(),
          'newPassword': _newPasswordController.text.trim(),
          'confirmNewPassword': _confirmPasswordController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() => _isUpdating = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        String mensajeExito = "Contraseña actualizada correctamente.";
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            if (data['mensaje'] != null && data['mensaje'].toString().isNotEmpty) {
              mensajeExito = data['mensaje'].toString();
            } else if (data['message'] != null && data['message'].toString().isNotEmpty) {
              mensajeExito = data['message'].toString();
            }

            if (data['token'] != null && data['token'].toString().isNotEmpty) {
              await AuthService.saveToken(data['token'].toString());
            }
            if (data['usuario'] != null && data['usuario'] is Map<String, dynamic>) {
              await AuthService.saveUserData(data['usuario'] as Map<String, dynamic>);
            }
          }
        } catch (_) {}

        if (!mounted) return;

        setState(() {
          _showSuccessBanner = true;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          _newPassword = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E5E3A),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mensajeExito,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: "X",
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        String errorMsg = "Error al actualizar la contraseña";
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            errorMsg = errorData['message'] ??
                errorData['mensaje'] ??
                errorData['error'] ??
                errorMsg;
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error de conexión: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMinLength = _newPassword.length >= 8;
    final hasLetterAndNumber = RegExp(r'(?=.*[a-zA-Z])(?=.*[0-9])').hasMatch(_newPassword);
    final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(_newPassword);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Institucional Oficial
              _buildInstitutionalHeader(),
              const SizedBox(height: 16),

              // Banner de éxito descartable si se actualizó
              if (_showSuccessBanner) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Contraseña actualizada correctamente.",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close, color: Color(0xFF15803D), size: 18),
                        onPressed: () => setState(() => _showSuccessBanner = false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 2. Título de pantalla
              const Text(
                "Seguridad",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F3A22),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                "Protege tu cuenta y administra las opciones de acceso a la aplicación.",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Tarjetas de opciones de seguridad
              _buildSecurityOptionsCard(),
              const SizedBox(height: 20),

              // 4. Formulario de Cambio de Contraseña
              _buildPasswordForm(
                hasMinLength: hasMinLength,
                hasLetterAndNumber: hasLetterAndNumber,
                hasSpecialChar: hasSpecialChar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // COMPONENTES MODULARES
  // ===========================================================================

  Widget _buildInstitutionalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F3A22), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          ClipOval(
            child: Image.asset(
              'assets/images/Logo verde.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Monitoreo Duende",
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F3A22),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  "PNR Páramo del Duende",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E4F3E),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F3A22), size: 25),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Cambiar contraseña
          ListTile(
            onTap: _scrollToPasswordForm,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.vpn_key_outlined, color: Color(0xFF1E5E3A), size: 20),
            ),
            title: const Text(
              "Cambiar contraseña",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            subtitle: const Text(
              "Actualiza tu contraseña de acceso",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 24),
          ),
          const Divider(height: 1, indent: 64, endIndent: 16),

          // 2. Autenticación biométrica
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            title: const Text(
              "Autenticación biométrica",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            subtitle: const Text(
              "Acceso rápido con huella o rostro",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            trailing: Switch(
              value: _biometricEnabled,
              activeThumbColor: const Color(0xFF1E5E3A),
              activeTrackColor: const Color(0xFFDCFCE7),
              onChanged: _toggleBiometric,
            ),
          ),
          const Divider(height: 1, indent: 64, endIndent: 16),

          // 3. Sesión activa
          ListTile(
            onTap: _showActiveSessionDialog,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_android_rounded, color: Color(0xFFD97706), size: 20),
            ),
            title: const Text(
              "Sesión activa",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            subtitle: const Text(
              "Estás usando este dispositivo",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm({
    required bool hasMinLength,
    required bool hasLetterAndNumber,
    required bool hasSpecialChar,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Color(0xFF1E5E3A), size: 22),
                SizedBox(width: 8),
                Text(
                  "Cambiar contraseña",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3A22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Ingresa tu clave actual y define una nueva que cumpla con los estándares de seguridad.",
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),

            // Contraseña actual *
            _buildPasswordField(
              label: "Contraseña actual *",
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) => v == null || v.trim().isEmpty ? "Ingresa tu contraseña actual" : null,
            ),
            const SizedBox(height: 14),

            // Nueva contraseña *
            _buildPasswordField(
              label: "Nueva contraseña *",
              controller: _newPasswordController,
              obscureText: _obscureNew,
              onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) => v == null || v.trim().isEmpty ? "Ingresa la nueva contraseña" : null,
            ),
            const SizedBox(height: 14),

            // Confirmar nueva contraseña *
            _buildPasswordField(
              label: "Confirmar nueva contraseña *",
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Confirma tu nueva contraseña";
                if (v != _newPasswordController.text) return "Las contraseñas no coinciden";
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Checklist de requisitos de seguridad
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Requisitos de seguridad:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  _buildRequirementItem(
                    label: "Mínimo 8 caracteres",
                    isSatisfied: hasMinLength,
                  ),
                  const SizedBox(height: 6),
                  _buildRequirementItem(
                    label: "Al menos una letra y un número",
                    isSatisfied: hasLetterAndNumber,
                  ),
                  const SizedBox(height: 6),
                  _buildRequirementItem(
                    label: "Un carácter especial (ej. @ # \$ %)",
                    isSatisfied: hasSpecialChar,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón ancho de actualizar contraseña
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _handleUpdatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5E3A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Actualizar contraseña",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: const Color(0xFF6B7280),
            size: 20,
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E5E3A), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildRequirementItem({
    required String label,
    required bool isSatisfied,
  }) {
    return Row(
      children: [
        Icon(
          isSatisfied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isSatisfied ? const Color(0xFF15803D) : const Color(0xFF9CA3AF),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSatisfied ? const Color(0xFF15803D) : const Color(0xFF6B7280),
            fontWeight: isSatisfied ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
