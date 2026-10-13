import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/login_screen/login_screen.dart';
import 'package:goblink_park/screens/profile/notification_settings_screen.dart';
import 'package:goblink_park/screens/profile/permissions_screen.dart';
import 'package:goblink_park/screens/profile/security_screen.dart';
import 'package:goblink_park/screens/profile/user_profile_view_screen.dart';
import 'package:goblink_park/services/user_service.dart';
import 'package:goblink_park/widgets/notification_bell_button.dart';

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
    UserService.userNotifier.addListener(_onGlobalUserUpdated);
    _loadProfile();
  }

  @override
  void dispose() {
    UserService.userNotifier.removeListener(_onGlobalUserUpdated);
    super.dispose();
  }

  void _onGlobalUserUpdated() {
    final updated = UserService.userNotifier.value;
    if (updated != null && mounted) {
      setState(() {
        _usuario = Map<String, dynamic>.from(updated);
      });
    }
  }

  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent && _usuario == null) {
      setState(() => _isLoading = true);
    }
    try {
      final token = await AuthStorage.getToken();
      Map<String, dynamic>? data =
          UserService.userNotifier.value ?? await AuthStorage.getUserData();

      if (data != null && mounted) {
        setState(() {
          _usuario = Map<String, dynamic>.from(data!);
          _isLoading = false;
        });
      }

      // Consumir datos reales de la BD vía GET /api/usuarios/perfil
      if (token != null && token.isNotEmpty) {
        try {
          final perfilData = await UserService.obtenerPerfil();
          if (perfilData != null) {
            data = perfilData;
          }
        } catch (e) {
          debugPrint('Error al obtener perfil desde API: $e');
        }
      }

      Map<String, dynamic> stats = Map<String, dynamic>.from(_estadisticas);

      final userId = data?['id'] ?? await AuthStorage.getUserId();

      if (userId != null && token != null && token.isNotEmpty) {
        try {
          final cleanToken = token.trim().startsWith('Bearer ')
              ? token.trim().substring(7).trim()
              : token.trim();
          final res = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/usuarios/$userId/estadisticas'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $cleanToken',
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
    final rawFoto = (_usuario?['fotoPerfilUrl'] ?? _usuario?['fotoPerfil'])?.toString();

    if (rawFoto != null && rawFoto.trim().isNotEmpty) {
      if (rawFoto.startsWith('http://') || rawFoto.startsWith('https://')) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: rawFoto,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            memCacheWidth: 600,
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
      _loadProfile(silent: true);
    }
  }

  // ===========================================================================
  // SOPORTE Y CIERRE DE SESIÓN
  // ===========================================================================

  void _showHelpSupportModal() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  "Ayuda y Soporte Institucional",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "PNR Páramo del Duende - Plataforma GoblinPark",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Para asistencia técnica en campo, reporte de anomalías o dudas sobre protocolos de monitoreo, comunícate con nuestro equipo:",
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                child: const Icon(Icons.mail_outline, color: Color(0xFF2563EB)),
              ),
              title: Text(
                "soporte@goblinpark.gov.co",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                "Atención técnica y científica 24/7",
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isDark ? const Color(0xFF1B4332) : const Color(0xFFE8F5E9),
                child: Icon(
                  Icons.phone_outlined,
                  color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                ),
              ),
              title: Text(
                "+57 (602) 224-5500",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                "Línea de emergencia Guardabosques",
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2D6A4F) : const Color(0xFF1E5E3A),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewPadding.bottom > 0
                ? MediaQuery.of(ctx).viewPadding.bottom + 12
                : 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3B1C1C)
                      : const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFD32F2F),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "¿Cerrar sesión?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Tendrás que volver a ingresar tus credenciales para acceder a tus reportes y mapas.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
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
                          backgroundColor: isDark
                              ? const Color(0xFF222E27)
                              : const Color(0xFFF3F4F6),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0xFFE5E7EB),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Cancelar",
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFF374151),
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      Text(
                        "Mi información",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Gestiona tu perfil, seguridad y preferencias de la cuenta",
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Goblin Park",
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  "PNR Páramo del Duende",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFA3B899) : const Color(0xFF2E4F3E),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBellButton(),
        ],
      ),
    );
  }

  Widget _buildUserSummaryCard({
    required String nombreCompleto,
    required String cargo,
    required String entidad,
  }) {
    final rawPortada = (_usuario?['fotoPortadaUrl'] ??
            _usuario?['fotoPortada'] ??
            _usuario?['foto_portada'])
        ?.toString()
        .trim();
    final hasPortada = rawPortada != null &&
        rawPortada.isNotEmpty &&
        (rawPortada.startsWith('http://') || rawPortada.startsWith('https://'));

    final ImageProvider coverImageProvider = hasPortada
        ? NetworkImage(rawPortada)
        : const AssetImage('assets/images/Fondo-Login.png');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: coverImageProvider,
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.35),
                BlendMode.darken,
              ),
            ),
          ),
          child: Container(
            // Capa de legibilidad (gradiente oscuro de izquierda a derecha)
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.25),
                ],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _navigateToUserProfileView,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Avatar circular con borde blanco/verde para resaltar sobre la portada
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.25),
                          border: Border.all(
                            color: const Color(0xFF52B788),
                            width: 2.2,
                          ),
                        ),
                        child: _buildAvatar(),
                      ),
                      const SizedBox(width: 14),

                      // Textos informativos con contraste sobre imagen
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge Usuario activo
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B4332).withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF52B788).withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: Color(0xFF6EE7B7),
                                    size: 7,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Usuario activo",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD1FAE5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),

                            // Nombre en blanco con sombra sutil
                            Text(
                              nombreCompleto,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0x8A000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),

                            // Cargo / Rol en verde claro brillante
                            Text(
                              cargo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA7F3D0),
                                shadows: [
                                  Shadow(
                                    color: Color(0x73000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),

                            // Entidad en blanco traslúcido legible
                            Text(
                              entidad,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.88),
                                shadows: const [
                                  Shadow(
                                    color: Color(0x73000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18231C) : const Color(0xFFEBF3EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x3352B788) : const Color(0xFFD1E3D7),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Mi participación en el proyecto",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF0F3A22),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22352B) : const Color(0xFFD6EBE0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "En tiempo real",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFD1E3D7),
          ),
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
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF22352B) : const Color(0xFFD6EBE0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dividerColor),
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
          Divider(height: 1, indent: 56, endIndent: 16, color: dividerColor),

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
          Divider(height: 1, indent: 56, endIndent: 16, color: dividerColor),

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
          Divider(height: 1, indent: 56, endIndent: 16, color: dividerColor),

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
          Divider(height: 1, indent: 56, endIndent: 16, color: dividerColor),

          // 5. Ayuda y soporte
          _buildOptionTile(
            icon: Icons.help_outline_rounded,
            title: "Ayuda y soporte",
            subtitle: "Preguntas frecuentes y contacto de campo",
            onTap: _showHelpSupportModal,
          ),
          Divider(height: 1, indent: 56, endIndent: 16, color: dividerColor),

          // 6. Cerrar sesión
          _buildOptionTile(
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBgColor: isDark ? const Color(0xFF3B1C1C) : const Color(0xFFFEE2E2),
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
    Color? iconColor,
    Color? iconBgColor,
    Color? titleColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveIconColor = iconColor ??
        (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A));
    final effectiveIconBgColor = iconBgColor ??
        (isDark ? const Color(0xFF1B4332) : const Color(0xFFE8F5E9));
    final effectiveTitleColor = titleColor ?? theme.colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: effectiveIconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: effectiveIconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: effectiveTitleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11.5,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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
