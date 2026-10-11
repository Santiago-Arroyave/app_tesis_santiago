import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/profile/edit_profile_screen.dart';
import 'package:goblink_park/screens/profile/notifications_screen.dart';

class UserProfileViewScreen extends StatefulWidget {
  final Map<String, dynamic>? usuario;
  final Map<String, dynamic>? estadisticas;

  const UserProfileViewScreen({
    super.key,
    this.usuario,
    this.estadisticas,
  });

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  final _picker = ImagePicker();
  late Map<String, dynamic> _usuario;
  late Map<String, dynamic> _estadisticas;
  bool _isUpdatingPhoto = false;

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario != null ? Map<String, dynamic>.from(widget.usuario!) : {};
    _estadisticas = widget.estadisticas != null ? Map<String, dynamic>.from(widget.estadisticas!) : {};
    _refreshUserData();
  }

  Future<void> _refreshUserData() async {
    final token = await AuthService.getToken();
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
          final perfilJson = jsonDecode(perfilRes.body);
          if (perfilJson is Map<String, dynamic>) {
            await AuthService.saveUserData(perfilJson);
            if (mounted) {
              setState(() {
                _usuario = perfilJson;
              });
            }
          }
        }

        final userId = _usuario['id'] ?? await AuthService.getUserId();
        if (userId != null) {
          final statsRes = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/usuarios/$userId/estadisticas'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 10));

          if (statsRes.statusCode == 200) {
            final statsJson = jsonDecode(statsRes.body);
            if (statsJson is Map<String, dynamic> && mounted) {
              setState(() {
                _estadisticas = statsJson;
              });
            }
          }
        }
        return;
      } catch (e) {
        debugPrint('Error refrescando perfil desde API: $e');
      }
    }

    final local = await AuthService.getUserData();
    if (local != null && mounted) {
      setState(() {
        _usuario = local;
      });
    }
  }

  Future<void> _navigateToEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(usuarioInicial: _usuario),
      ),
    );

    if (updated == true && mounted) {
      await _refreshUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Perfil actualizado en la vista"),
            backgroundColor: Color(0xFF1E5E3A),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 18),
            const Text(
              "Cambiar foto de perfil",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3A22),
              ),
            ),
            const SizedBox(height: 16),
            // 1. Tomar foto
            _buildPhotoOptionCard(
              icon: Icons.camera_alt,
              iconColor: const Color(0xFF1E5E3A),
              iconBgColor: const Color(0xFFE8F5E9),
              title: "Tomar foto",
              subtitle: "Usa la cámara de tu dispositivo",
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            // 2. Seleccionar de galería
            _buildPhotoOptionCard(
              icon: Icons.image_outlined,
              iconColor: const Color(0xFF1E5E3A),
              iconBgColor: const Color(0xFFE8F5E9),
              title: "Seleccionar de galería",
              subtitle: "Elige una foto de tu galería",
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
            // 3. Eliminar foto actual
            _buildPhotoOptionCard(
              icon: Icons.delete_outline,
              iconColor: const Color(0xFFE53935),
              iconBgColor: const Color(0xFFFFEBEE),
              title: "Eliminar foto actual",
              titleColor: const Color(0xFFE53935),
              subtitle: "Se quitará tu foto de perfil",
              arrowColor: const Color(0xFFE53935),
              onTap: () {
                Navigator.pop(ctx);
                _deleteCurrentPhoto();
              },
            ),
            const SizedBox(height: 20),
            // Botón Cancelar
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOptionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color titleColor = const Color(0xFF111827),
    Color arrowColor = const Color(0xFF9CA3AF),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: arrowColor, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUpdatingPhoto = true);

      final token = await AuthService.getToken();
      final file = File(picked.path);

      if (token != null && token.isNotEmpty) {
        try {
          final uri = Uri.parse('${ApiConfig.baseUrl}/api/usuarios/perfil');
          final request = http.MultipartRequest('PUT', uri);
          request.headers['Authorization'] = 'Bearer $token';
          request.files.add(await http.MultipartFile.fromPath('fotoPerfil', file.path));

          final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
          if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
            final resStr = await streamedResponse.stream.bytesToString();
            try {
              final backendData = jsonDecode(resStr);
              if (backendData is Map<String, dynamic>) {
                final current = await AuthService.getUserData() ?? _usuario;
                final merged = Map<String, dynamic>.from(current)..addAll(backendData);
                await AuthService.saveUserData(merged);
              }
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('Backend upload foto: $e');
        }
      }

      await _refreshUserData();
      if (!mounted) return;
      setState(() => _isUpdatingPhoto = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Foto de perfil actualizada correctamente"),
          backgroundColor: Color(0xFF1E5E3A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al cambiar foto: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCurrentPhoto() async {
    setState(() => _isUpdatingPhoto = true);

    try {
      final token = await AuthService.getToken();
      final updatedData = Map<String, dynamic>.from(_usuario);
      updatedData['fotoPerfil'] = '';
      await AuthService.saveUserData(updatedData);

      if (token != null && token.isNotEmpty) {
        try {
          final uri = Uri.parse('${ApiConfig.baseUrl}/api/usuarios/perfil');
          final request = http.MultipartRequest('PUT', uri);
          request.headers['Authorization'] = 'Bearer $token';
          request.fields['fotoPerfil'] = '';

          final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
          if (streamedResponse.statusCode == 200) {
            final resStr = await streamedResponse.stream.bytesToString();
            try {
              final backendData = jsonDecode(resStr);
              if (backendData is Map<String, dynamic>) {
                final merged = Map<String, dynamic>.from(updatedData)..addAll(backendData);
                await AuthService.saveUserData(merged);
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      await _refreshUserData();
      if (!mounted) return;
      setState(() => _isUpdatingPhoto = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Foto de perfil eliminada"),
          backgroundColor: Color(0xFF1E5E3A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al eliminar foto: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatFechaRegistro(dynamic fechaVal) {
    if (fechaVal == null) return '12 de marzo de 2024';
    final str = fechaVal.toString();
    try {
      final dt = DateTime.parse(str);
      const months = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];
      return '${dt.day} de ${months[dt.month - 1]} de ${dt.year}';
    } catch (_) {
      if (str.length >= 10) return str.substring(0, 10);
      return str;
    }
  }

  Widget _buildAvatarImage() {
    if (_isUpdatingPhoto) {
      return Container(
        width: 86,
        height: 86,
        decoration: const BoxDecoration(
          color: Color(0xFFE8F5E9),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF1E5E3A),
          ),
        ),
      );
    }

    final rawFoto = _usuario['fotoPerfil']?.toString();
    if (rawFoto != null && rawFoto.trim().isNotEmpty) {
      if (rawFoto.startsWith('http://') || rawFoto.startsWith('https://')) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: rawFoto,
            width: 86,
            height: 86,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 86,
              height: 86,
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
            width: 86,
            height: 86,
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
      width: 86,
      height: 86,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        size: 50,
        color: Color(0xFF1E5E3A),
      ),
    );
  }

  Widget _buildCoverBanner() {
    final rawPortada = _usuario['fotoPortada']?.toString();
    if (rawPortada != null && rawPortada.trim().isNotEmpty) {
      if (rawPortada.startsWith('http://') || rawPortada.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: rawPortada,
          width: double.infinity,
          height: 140,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: double.infinity,
            height: 140,
            color: Colors.grey[200],
          ),
          errorWidget: (context, url, error) => Image.asset(
            'assets/images/Fondo-Login.png',
            width: double.infinity,
            height: 140,
            fit: BoxFit.cover,
          ),
        );
      }
      try {
        String clean = rawPortada;
        if (clean.contains(',')) {
          clean = clean.split(',').last;
        }
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: 140,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Image.asset(
            'assets/images/Fondo-Login.png',
            width: double.infinity,
            height: 140,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return Image.asset(
          'assets/images/Fondo-Login.png',
          width: double.infinity,
          height: 140,
          fit: BoxFit.cover,
        );
      }
    }

    return Image.asset(
      'assets/images/Fondo-Login.png',
      width: double.infinity,
      height: 140,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombres = _usuario['nombres']?.toString() ?? '';
    final apellidos = _usuario['apellidos']?.toString() ?? '';
    final fullName = '$nombres $apellidos'.trim();
    final nombreCompleto = fullName.isNotEmpty ? fullName : (_usuario['username']?.toString() ?? 'Usuario GoblinPark');

    final cargo = (_usuario['cargoRol'] ?? _usuario['cargo_rol'] ?? _usuario['cargo'] ?? _usuario['rolNombre'] ?? _usuario['rol'])?.toString() ?? 'Sin cargo asignado';
    final entidad = _usuario['entidad']?.toString() ?? 'Sin entidad';
    final documento = (_usuario['documentoIdentidad'] ?? _usuario['documento'] ?? _usuario['cedula'])?.toString() ?? 'No registrado';
    final correo = _usuario['correo']?.toString() ?? '';
    final telefono = _usuario['telefono']?.toString() ?? 'No registrado';
    final municipio = (_usuario['municipioResidencia'] ?? _usuario['municipio_residencia'] ?? _usuario['municipio'])?.toString() ?? 'No registrado';
    final sobreMi = (_usuario['sobreMi'] ?? _usuario['sobre_mi'])?.toString() ?? '';
    final fechaIngreso = _formatFechaRegistro(_usuario['fechaRegistro'] ?? _usuario['fechaCreacion']);

    final int totalProyectos = (_estadisticas['totalProyectos'] as num?)?.toInt() ?? 0;
    final int totalReportes = (_estadisticas['totalReportes'] as num?)?.toInt() ?? 0;
    final int totalEvidencias = (_estadisticas['totalEvidencias'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Institucional
              _buildInstitutionalHeader(),
              const SizedBox(height: 16),

              // 2. Título de pantalla: "Perfil"
              const Text(
                "Perfil",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F3A22),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 14),

              // 3. Banner de Portada con Avatar superpuesto
              _buildCoverAndAvatarSection(),
              const SizedBox(height: 14),

              // 4. Datos de identidad y rol
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreCompleto,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cargo,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E5E3A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entidad,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Color(0xFF15803D), size: 7.5),
                        SizedBox(width: 4.5),
                        Text(
                          "Usuario activo",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (sobreMi.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    sobreMi,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF4B5563),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 5. Tarjeta "Mi participación en el proyecto" (Verde Suave)
              _buildParticipationCard(
                proyectos: totalProyectos,
                reportes: totalReportes,
                evidencias: totalEvidencias,
              ),
              const SizedBox(height: 18),

              // 6. Sección "Información personal" con botón "Editar"
              _buildPersonalInformationSection(
                documento: documento,
                correo: correo,
                telefono: telefono,
                municipio: municipio,
                entidad: entidad,
                cargo: cargo,
                fechaIngreso: fechaIngreso,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGETS MODULARES
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
            onPressed: () => Navigator.pop(context, true),
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

  Widget _buildCoverAndAvatarSection() {
    return SizedBox(
      height: 185,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner de Portada
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: double.infinity,
              height: 140,
              child: _buildCoverBanner(),
            ),
          ),

          // Avatar superpuesto en la esquina inferior izquierda
          Positioned(
            left: 16,
            bottom: 0,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _showPhotoOptions,
                      child: _buildAvatarImage(),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: const Color(0xFF1E5E3A),
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _showPhotoOptions,
                      child: const Padding(
                        padding: EdgeInsets.all(7.5),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Botón rápido de edición flotante sobre el banner
          Positioned(
            right: 12,
            top: 12,
            child: Material(
              color: Colors.white.withAlpha(220),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _showPhotoOptions,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1E5E3A)),
                      SizedBox(width: 4),
                      Text(
                        "Editar foto",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E5E3A),
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

  Widget _buildParticipationCard({
    required int proyectos,
    required int reportes,
    required int evidencias,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD1E3D7), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Mi participación en el proyecto",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F3A22),
            ),
          ),
          const SizedBox(height: 12),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD1E3D7)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFD6EBE0),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF1E5E3A), size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F3A22),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInformationSection({
    required String documento,
    required String correo,
    required String telefono,
    required String municipio,
    required String entidad,
    required String cargo,
    required String fechaIngreso,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Información personal",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3A22),
                ),
              ),
              // Botón estilizado "Editar"
              OutlinedButton.icon(
                onPressed: _navigateToEdit,
                icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1E5E3A)),
                label: const Text(
                  "Editar",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5E3A),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F5E9),
                  side: const BorderSide(color: Color(0xFF1E5E3A), width: 1.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow(Icons.badge_outlined, "Documento", "CC $documento"),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.email_outlined, "Correo electrónico", correo),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone_outlined, "Teléfono", telefono),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.place_outlined, "Municipio de residencia", municipio),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.corporate_fare_outlined, "Entidad", entidad),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.work_outline, "Cargo / Rol", cargo),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.calendar_month_outlined, "Fecha de ingreso", fechaIngreso),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1E5E3A)),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}
