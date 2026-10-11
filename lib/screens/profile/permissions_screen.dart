import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:goblink_park/screens/profile/notifications_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  bool _isLocationGranted = false;
  bool _isCameraGranted = false;
  bool _isGalleryGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-verificar permisos al volver de la pantalla de configuración del sistema
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    try {
      // 1. Ubicación (Geolocator + PermissionHandler)
      final geoPermission = await Geolocator.checkPermission();
      final locStatus = await Permission.location.status;
      final locGranted = geoPermission == LocationPermission.always ||
          geoPermission == LocationPermission.whileInUse ||
          locStatus.isGranted ||
          locStatus.isLimited;

      // 2. Cámara
      final camStatus = await Permission.camera.status;
      final camGranted = camStatus.isGranted || camStatus.isLimited;

      // 3. Galería / Almacenamiento
      final photosStatus = await Permission.photos.status;
      final storageStatus = await Permission.storage.status;
      final galleryGranted = photosStatus.isGranted ||
          photosStatus.isLimited ||
          storageStatus.isGranted ||
          storageStatus.isLimited;

      if (!mounted) return;
      setState(() {
        _isLocationGranted = locGranted;
        _isCameraGranted = camGranted;
        _isGalleryGranted = galleryGranted;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestLocation() async {
    final status = await Permission.location.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    await _checkAllPermissions();
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    await _checkAllPermissions();
  }

  Future<void> _requestGallery() async {
    await Permission.photos.request();
    await Permission.storage.request();
    await _checkAllPermissions();
  }

  Future<void> _openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {
      await Geolocator.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Institucional Oficial
              _buildInstitutionalHeader(),
              const SizedBox(height: 16),

              // 2. Título de pantalla
              const Text(
                "Permisos y ubicación",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F3A22),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                "Necesitamos algunos permisos para que puedas georreferenciar tus reportes y subir evidencias desde el campo.",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Banner del Páramo con tarjeta superpuesta
              _buildParamoBanner(),
              const SizedBox(height: 20),

              // 4. Lista de Permisos del Sistema
              const Text(
                "Permisos requeridos",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3A22),
                ),
              ),
              const SizedBox(height: 8),
              _buildPermissionsList(),
              const SizedBox(height: 20),

              // 5. Tarjeta Inferior de Gestión
              _buildManagementCard(),
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

  Widget _buildParamoBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Imagen panorámica de fondo del páramo
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/Fondo-Login.png',
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          // Sombra suave sobre la imagen
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(40),
                  Colors.black.withAlpha(120),
                ],
              ),
            ),
          ),
          // Tarjeta superpuesta blanca informativa
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(245),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    radius: 18,
                    child: Icon(Icons.location_on, color: Color(0xFF1E5E3A), size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Tu ubicación y las evidencias nos ayudan a generar información confiable para la conservación del Páramo del Duende.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F3A22),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsList() {
    if (_isLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E5E3A), strokeWidth: 2),
        ),
      );
    }

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
          // 1. Ubicación
          _buildPermissionTile(
            icon: Icons.location_on,
            title: "Ubicación",
            subtitle: "Permite georreferenciar tus reportes.",
            isGranted: _isLocationGranted,
            onTap: _isLocationGranted ? _openSettings : _requestLocation,
          ),
          const Divider(height: 1, indent: 64, endIndent: 16),

          // 2. Cámara
          _buildPermissionTile(
            icon: Icons.camera_alt,
            title: "Cámara",
            subtitle: "Se usa para tomar fotos de evidencias en campo.",
            isGranted: _isCameraGranted,
            onTap: _isCameraGranted ? _openSettings : _requestCamera,
          ),
          const Divider(height: 1, indent: 64, endIndent: 16),

          // 3. Galería
          _buildPermissionTile(
            icon: Icons.photo_library,
            title: "Galería",
            subtitle: "Permite seleccionar fotos y videos desde tu dispositivo.",
            isGranted: _isGalleryGranted,
            onTap: _isGalleryGranted ? _openSettings : _requestGallery,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isGranted ? const Color(0xFFE8F5E9) : const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isGranted ? const Color(0xFF1E5E3A) : const Color(0xFF6B7280),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
      ),
      trailing: _buildStatusPill(isGranted),
    );
  }

  Widget _buildStatusPill(bool isGranted) {
    if (isGranted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 12),
            SizedBox(width: 4),
            Text(
              "Permitido",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_outlined, color: Color(0xFF6B7280), size: 12),
          SizedBox(width: 4),
          Text(
            "No permitido",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, color: Color(0xFF1E5E3A), size: 20),
              SizedBox(width: 8),
              Text(
                "Gestionar permisos",
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3A22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Puedes modificar estos permisos en la configuración de tu dispositivo en cualquier momento.",
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.open_in_new_rounded, size: 17, color: Color(0xFF1E5E3A)),
              label: const Text(
                "Abrir configuración",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E5E3A)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E5E3A), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
