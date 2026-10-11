import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/login_screen/login_screen.dart';
import 'package:goblink_park/screens/profile/notification_settings_screen.dart';
import 'package:goblink_park/screens/profile/notifications_screen.dart';
import 'package:goblink_park/screens/profile/permissions_screen.dart';
import 'package:goblink_park/screens/profile/security_screen.dart';
import 'package:goblink_park/screens/profile/user_profile_view_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _usuario;
  Map<String, dynamic> _estadisticas = {
    'totalProyectos': 0,
    'totalReportes': 0,
    'totalEvidencias': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      Map<String, dynamic>? data = await AuthService.getUserData();

      // Consumir datos reales de la BD vía GET /api/usuarios/perfil
      if (token != null && token.isNotEmpty) {
        try {
          final perfilRes = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/usuarios/perfil'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 10));

          if (perfilRes.statusCode == 200) {
            final decoded = jsonDecode(perfilRes.body);
            if (decoded is Map<String, dynamic>) {
              data = decoded;
              await AuthService.saveUserData(decoded);
            }
          }
        } catch (e) {
          debugPrint('Error al obtener perfil desde API: $e');
        }
      }

      Map<String, dynamic> stats = {
        'totalProyectos': 0,
        'totalReportes': 0,
        'totalEvidencias': 0,
      };

      final userId = data?['id'] ?? await AuthService.getUserId();

      if (userId != null && token != null && token.isNotEmpty) {
        try {
          final res = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/usuarios/$userId/estadisticas'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 10));

          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            if (decoded is Map<String, dynamic>) {
              stats = decoded;
            }
          }
        } catch (e) {
          debugPrint('Error al obtener estadísticas del usuario: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _usuario = data;
        _estadisticas = stats;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAvatar() {
    final rawFoto = _usuario?['fotoPerfil']?.toString();

    if (rawFoto != null && rawFoto.trim().isNotEmpty) {
      if (rawFoto.startsWith('http://') || rawFoto.startsWith('https://')) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: rawFoto,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 72,
              height: 72,
              color: Colors.grey[200],
            ),
            errorWidget: (context, url, error) => _defaultAvatar(),
          ),
        );
      }
      try {
        String clean = rawFoto;
        if (clean.contains(',')) {
          clean = clean.split(',').last;
        }
        final bytes = base64Decode(clean);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _defaultAvatar(),
          ),
        );
      } catch (_) {
        return _defaultAvatar();
      }
    }

    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        size: 42,
        color: Color(0xFF1E5E3A),
      ),
    );
  }

  Future<void> _navigateToUserProfileView() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileViewScreen(
          usuario: _usuario,
          estadisticas: _estadisticas,
        ),
      ),
    );
    if (mounted) {
      _loadProfile();
    }
  }

  // ===========================================================================
  // SOPORTE Y CIERRE DE SESIÓN
  // ===========================================================================

  void _showHelpSupportModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.help_outline_rounded, color: Color(0xFF1E5E3A), size: 22),
                SizedBox(width: 8),
                Text(
                  "Ayuda y Soporte Institucional",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3A22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "PNR Páramo del Duende - Plataforma GoblinPark",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 6),
            const Text(
              "Para asistencia técnica en campo, reporte de anomalías o dudas sobre protocolos de monitoreo, comunícate con nuestro equipo:",
              style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.mail_outline, color: Color(0xFF2563EB)),
              ),
              title: const Text("soporte@goblinpark.gov.co", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text("Atención técnica y científica 24/7", style: TextStyle(fontSize: 11.5)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.phone_outlined, color: Color(0xFF1E5E3A)),
              ),
              title: const Text("+57 (602) 224-5500", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text("Línea de emergencia Guardabosques", style: TextStyle(fontSize: 11.5)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5E3A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Cerrar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Diálogo modal de confirmación de cierre de sesión en BottomSheet
  Future<void> _showLogoutDialog() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFD32F2F),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "¿Cerrar sesión?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tendrás que volver a ingresar tus credenciales para acceder a tus reportes y mapas.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Cancelar",
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Sí, cerrar sesión",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombres = _usuario?['nombres']?.toString() ?? '';
    final apellidos = _usuario?['apellidos']?.toString() ?? '';
    final fullName = '$nombres $apellidos'.trim();
    final nombreCompleto = _usuario?['nombreCompleto']?.toString() ??
        (fullName.isNotEmpty ? fullName : (_usuario?['username']?.toString() ?? 'Usuario GoblinPark'));
    final cargo = (_usuario?['cargoRol'] ??
            _usuario?['cargo_rol'] ??
            _usuario?['cargo'] ??
            _usuario?['rolNombre'] ??
            _usuario?['rol'])
        ?.toString() ??
        'Guardabosques';
    final entidad = _usuario?['entidad']?.toString() ?? 'Parques Nacionales Naturales';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1E5E3A),
                  strokeWidth: 2.5,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadProfile,
                color: const Color(0xFF1E5E3A),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Header Superior Institucional
                      _buildInstitutionalHeader(),
                      const SizedBox(height: 16),

                      // 2. Título de vista: "Mi información"
                      const Text(
                        "Mi información",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F3A22),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "Gestiona tu perfil, seguridad y preferencias de la cuenta",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Tarjeta de usuario destacada (Avatar & Resumen)
                      _buildUserSummaryCard(
                        nombreCompleto: nombreCompleto,
                        cargo: cargo,
                        entidad: entidad,
                      ),
                      const SizedBox(height: 16),

                      // 4. Métricas de participación del usuario
                      _buildMetricsRow(),
                      const SizedBox(height: 20),

                      // 5. Lista de opciones de gestión
                      _buildOptionsSection(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ===========================================================================
  // COMPONENTES VISUALES
  // ===========================================================================

  Widget _buildInstitutionalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ClipOval(
            child: Image.asset(
              'assets/images/Logo verde.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F3A22), size: 25),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E5E3A),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserSummaryCard({
    required String nombreCompleto,
    required String cargo,
    required String entidad,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _navigateToUserProfileView,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar circular con borde verde institucional
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1E5E3A), width: 2.2),
                  ),
                  child: _buildAvatar(),
                ),
                const SizedBox(width: 14),

                // Textos informativos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Usuario activo
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Color(0xFF15803D), size: 7),
                            SizedBox(width: 4),
                            Text(
                              "Usuario activo",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Nombre
                      Text(
                        nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Cargo / Rol
                      Text(
                        cargo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E5E3A),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Entidad
                      Text(
                        entidad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsRow() {
    final int proyectos = (_estadisticas['totalProyectos'] as num?)?.toInt() ?? 0;
    final int reportes = (_estadisticas['totalReportes'] as num?)?.toInt() ?? 0;
    final int evidencias = (_estadisticas['totalEvidencias'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD1E3D7), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Mi participación en el proyecto",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F3A22),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6EBE0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "En tiempo real",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5E3A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMetricItem(Icons.folder_outlined, proyectos.toString(), "Proyectos"),
              const SizedBox(width: 8),
              _buildMetricItem(Icons.assignment_outlined, reportes.toString(), "Reportes"),
              const SizedBox(width: 8),
              _buildMetricItem(Icons.photo_camera_outlined, evidencias.toString(), "Evidencias"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String count, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD1E3D7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFD6EBE0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: const Color(0xFF1E5E3A), size: 20),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              count,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F3A22),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection() {
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
          // 1. Editar perfil
          _buildOptionTile(
            icon: Icons.person_outline,
            title: "Editar perfil",
            subtitle: "Actualiza tu información personal",
            onTap: _navigateToUserProfileView,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 2. Seguridad
          _buildOptionTile(
            icon: Icons.lock_outline,
            title: "Seguridad",
            subtitle: "Contraseña y acceso a la cuenta",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecurityScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 3. Notificaciones
          _buildOptionTile(
            icon: Icons.notifications_none_rounded,
            title: "Notificaciones",
            subtitle: "Preferencias de alertas ambientales",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 4. Permisos
          _buildOptionTile(
            icon: Icons.security_outlined,
            title: "Permisos",
            subtitle: "Ubicación, cámara y galería",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PermissionsScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 5. Ayuda y soporte
          _buildOptionTile(
            icon: Icons.help_outline_rounded,
            title: "Ayuda y soporte",
            subtitle: "Preguntas frecuentes y contacto de campo",
            onTap: _showHelpSupportModal,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),

          // 6. Cerrar sesión
          _buildOptionTile(
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBgColor: const Color(0xFFFEE2E2),
            title: "Cerrar sesión",
            titleColor: const Color(0xFFDC2626),
            subtitle: "Finalizar sesión en este dispositivo",
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF1E5E3A),
    Color iconBgColor = const Color(0xFFE8F5E9),
    Color titleColor = const Color(0xFF111827),
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11.5,
          color: Color(0xFF6B7280),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFF9CA3AF),
        size: 22,
      ),
    );
  }
}
