import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? usuarioInicial;

  const EditProfileScreen({
    super.key,
    this.usuarioInicial,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _baseUrl = ApiConfig.baseUrl;

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController _nombresController;
  late TextEditingController _apellidosController;
  late TextEditingController _correoController;
  late TextEditingController _documentoController;
  late TextEditingController _telefonoController;
  late TextEditingController _entidadController;
  late TextEditingController _cargoRolController;
  late TextEditingController _municipioController;
  late TextEditingController _sobreMiController;

  String? _fotoPerfilUrl;
  File? _fotoPerfilFile;
  bool _fotoEliminada = false;

  String? _fotoPortadaUrl;
  File? _fotoPortadaFile;
  bool _fotoPortadaEliminada = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.usuarioInicial ?? {};

    _nombresController = TextEditingController(text: u['nombres']?.toString() ?? '');
    _apellidosController = TextEditingController(text: u['apellidos']?.toString() ?? '');
    _correoController = TextEditingController(text: u['correo']?.toString() ?? '');
    _documentoController = TextEditingController(
      text: (u['documentoIdentidad'] ?? u['documento'] ?? u['cedula'] ?? u['numeroDocumento'])?.toString() ?? '',
    );
    _telefonoController = TextEditingController(text: u['telefono']?.toString() ?? '');
    _entidadController = TextEditingController(
      text: u['entidad']?.toString() ?? '',
    );
    _cargoRolController = TextEditingController(
      text: (u['cargoRol'] ?? u['cargo_rol'] ?? u['cargo'] ?? u['rolNombre'])?.toString() ?? '',
    );
    _municipioController = TextEditingController(
      text: (u['municipioResidencia'] ?? u['municipio_residencia'] ?? u['municipio'])?.toString() ?? '',
    );
    _sobreMiController = TextEditingController(
      text: (u['sobreMi'] ?? u['sobre_mi'] ?? u['descripcion'])?.toString() ?? '',
    );

    final rawFoto = (u['fotoPerfilUrl'] ?? u['fotoPerfil'])?.toString();
    if (rawFoto != null && rawFoto.isNotEmpty) {
      _fotoPerfilUrl = rawFoto;
    }

    final rawPortada = (u['fotoPortadaUrl'] ?? u['fotoPortada'])?.toString();
    if (rawPortada != null && rawPortada.isNotEmpty) {
      _fotoPortadaUrl = rawPortada;
    }
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _correoController.dispose();
    _documentoController.dispose();
    _telefonoController.dispose();
    _entidadController.dispose();
    _cargoRolController.dispose();
    _municipioController.dispose();
    _sobreMiController.dispose();
    super.dispose();
  }

  void _showCoverPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text(
              "Foto de portada",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3A22),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.camera_alt_outlined, color: Color(0xFF1E5E3A)),
              ),
              title: const Text("Tomar foto", style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickCoverImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
              ),
              title: const Text("Seleccionar de galería", style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickCoverImage(ImageSource.gallery);
              },
            ),
            if (_fotoPortadaFile != null || (_fotoPortadaUrl != null && !_fotoPortadaEliminada))
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEE2E2),
                  child: Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                ),
                title: const Text(
                  "Restablecer portada institucional",
                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _fotoPortadaFile = null;
                    _fotoPortadaUrl = null;
                    _fotoPortadaEliminada = true;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCoverImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _fotoPortadaFile = File(picked.path);
          _fotoPortadaEliminada = false;
        });
      }
    } catch (e) {
      debugPrint('Error al seleccionar portada: $e');
    }
  }

  Widget _buildCoverPreview() {
    if (_fotoPortadaFile != null) {
      return Image.file(
        _fotoPortadaFile!,
        width: double.infinity,
        height: 140,
        fit: BoxFit.cover,
      );
    }

    if (_fotoPortadaUrl != null && !_fotoPortadaEliminada) {
      final raw = _fotoPortadaUrl!;
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: raw,
          width: double.infinity,
          height: 140,
          fit: BoxFit.cover,
          memCacheWidth: 600,
          placeholder: (context, url) => Container(
            width: double.infinity,
            height: 140,
            color: Colors.grey[200],
          ),
          errorWidget: (context, url, error) => _defaultCoverAsset(),
        );
      }
      try {
        String clean = raw;
        if (clean.contains(',')) {
          clean = clean.split(',').last;
        }
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: 140,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _defaultCoverAsset(),
        );
      } catch (_) {
        return _defaultCoverAsset();
      }
    }

    return _defaultCoverAsset();
  }

  Widget _defaultCoverAsset() {
    return Image.asset(
      'assets/images/Fondo-Login.png',
      width: double.infinity,
      height: 140,
      fit: BoxFit.cover,
    );
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
                _pickImage(ImageSource.camera);
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
                _pickImage(ImageSource.gallery);
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
                setState(() {
                  _fotoPerfilFile = null;
                  _fotoPerfilUrl = null;
                  _fotoEliminada = true;
                });
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _fotoPerfilFile = File(picked.path);
          _fotoEliminada = false;
        });
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
    }
  }

  Widget _buildAvatarPreview() {
    if (_fotoPerfilFile != null) {
      return ClipOval(
        child: Image.file(
          _fotoPerfilFile!,
          width: 86,
          height: 86,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_fotoPerfilUrl != null && !_fotoEliminada) {
      final raw = _fotoPerfilUrl!;
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: raw,
            width: 86,
            height: 86,
            fit: BoxFit.cover,
            memCacheWidth: 600,
            placeholder: (context, url) => Container(
              width: 86,
              height: 86,
              color: Colors.grey[200],
            ),
            errorWidget: (context, url, error) => _defaultAvatarIcon(),
          ),
        );
      }
      try {
        String clean = raw;
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
            errorBuilder: (_, _, _) => _defaultAvatarIcon(),
          ),
        );
      } catch (_) {
        return _defaultAvatarIcon();
      }
    }

    return _defaultAvatarIcon();
  }

  Widget _defaultAvatarIcon() {
    return Container(
      width: 86,
      height: 86,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 48, color: Color(0xFF1E5E3A)),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final token = await AuthService.getToken();
      final currentLocal = await AuthService.getUserData() ?? {};

      // Mapa actualizado consolidando claves camelCase y snake_case para compatibilidad total
      final updatedData = Map<String, dynamic>.from(currentLocal);
      updatedData['nombres'] = _nombresController.text.trim();
      updatedData['apellidos'] = _apellidosController.text.trim();
      updatedData['nombreCompleto'] =
          '${_nombresController.text.trim()} ${_apellidosController.text.trim()}'.trim();
      updatedData['correo'] = _correoController.text.trim();
      updatedData['documento'] = _documentoController.text.trim();
      updatedData['cedula'] = _documentoController.text.trim();
      updatedData['telefono'] = _telefonoController.text.trim();
      updatedData['entidad'] = _entidadController.text.trim();
      updatedData['cargoRol'] = _cargoRolController.text.trim();
      updatedData['cargo_rol'] = _cargoRolController.text.trim();
      updatedData['municipioResidencia'] = _municipioController.text.trim();
      updatedData['municipio_residencia'] = _municipioController.text.trim();
      updatedData['sobreMi'] = _sobreMiController.text.trim();
      updatedData['sobre_mi'] = _sobreMiController.text.trim();

      if (_fotoEliminada) {
        updatedData['fotoPerfil'] = '';
      } else if (_fotoPerfilUrl != null && _fotoPerfilFile == null) {
        updatedData['fotoPerfil'] = _fotoPerfilUrl;
      }

      if (_fotoPortadaEliminada) {
        updatedData['fotoPortada'] = '';
      } else if (_fotoPortadaUrl != null && _fotoPortadaFile == null) {
        updatedData['fotoPortada'] = _fotoPortadaUrl;
      }

      // 1. Guardar localmente de inmediato (resiliencia offline)
      await AuthService.saveUserData(updatedData);

      // 2. Intentar sincronizar con backend si hay token
      if (token != null && token.isNotEmpty) {
        try {
          final uri = Uri.parse('$_baseUrl/api/usuarios/perfil');
          final request = http.MultipartRequest('PUT', uri);
          request.headers['Authorization'] = 'Bearer $token';

          request.fields['nombres'] = _nombresController.text.trim();
          request.fields['apellidos'] = _apellidosController.text.trim();
          request.fields['telefono'] = _telefonoController.text.trim();
          request.fields['documento'] = _documentoController.text.trim();
          request.fields['documentoIdentidad'] = _documentoController.text.trim();
          request.fields['entidad'] = _entidadController.text.trim();
          request.fields['cargoRol'] = _cargoRolController.text.trim();
          request.fields['cargo_rol'] = _cargoRolController.text.trim();
          request.fields['municipioResidencia'] = _municipioController.text.trim();
          request.fields['municipio_residencia'] = _municipioController.text.trim();
          request.fields['sobreMi'] = _sobreMiController.text.trim();
          request.fields['sobre_mi'] = _sobreMiController.text.trim();

          if (_fotoPerfilFile != null) {
            request.files.add(
              await http.MultipartFile.fromPath('fotoPerfil', _fotoPerfilFile!.path),
            );
          } else if (_fotoEliminada) {
            request.fields['fotoPerfil'] = '';
          }

          if (_fotoPortadaFile != null) {
            request.files.add(
              await http.MultipartFile.fromPath('fotoPortada', _fotoPortadaFile!.path),
            );
          } else if (_fotoPortadaEliminada) {
            request.fields['fotoPortada'] = '';
          }

          final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
          if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
            final resStr = await streamedResponse.stream.bytesToString();
            try {
              final backendData = jsonDecode(resStr);
              if (backendData is Map<String, dynamic>) {
                final merged = Map<String, dynamic>.from(updatedData)..addAll(backendData);
                await AuthService.saveUserData(merged);
              }
            } catch (_) {}
          }
        } catch (netErr) {
          debugPrint('Backend no respondió, pero los datos se guardaron localmente: $netErr');
        }
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Perfil actualizado correctamente"),
          backgroundColor: Color(0xFF1E5E3A),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al guardar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F3A22)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Editar información",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F3A22),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Banner de portada y Avatar editable superpuesto
              SizedBox(
                height: 195,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Banner de portada
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: double.infinity,
                        height: 140,
                        child: _buildCoverPreview(),
                      ),
                    ),
                    // Botón para cambiar foto de portada
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Material(
                        color: Colors.white.withAlpha(225),
                        borderRadius: BorderRadius.circular(16),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _showCoverPhotoOptions,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_outlined, size: 14, color: Color(0xFF1E5E3A)),
                                SizedBox(width: 5),
                                Text(
                                  "Cambiar portada",
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
                    // Avatar superpuesto
                    Positioned(
                      left: 18,
                      bottom: 0,
                      child: Stack(
                        clipBehavior: Clip.none,
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
                            child: _buildAvatarPreview(),
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
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Tarjeta con campos de información personal
              _buildSectionCard(
                title: "Información Básica",
                icon: Icons.person_outline,
                children: [
                  _buildTextField(
                    label: "Nombres",
                    controller: _nombresController,
                    hint: "Ej. Ana María",
                    validator: (v) => v == null || v.trim().isEmpty ? "Ingresa tus nombres" : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: "Apellidos",
                    controller: _apellidosController,
                    hint: "Ej. Morales Gómez",
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: "Correo electrónico",
                    controller: _correoController,
                    hint: "correo@ejemplo.com",
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF9CA3AF)),
                    helperText: "El correo electrónico no puede modificarse",
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: "Documento de identidad",
                    controller: _documentoController,
                    hint: "C.C. / T.I. / Pasaporte",
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: "Teléfono de contacto",
                    controller: _telefonoController,
                    hint: "Ej. +57 312 345 6789",
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Tarjeta con cargo, entidad y residencia
              _buildSectionCard(
                title: "Rol Institucional y Ubicación",
                icon: Icons.work_outline,
                children: [
                  _buildTextField(
                    label: "Entidad u Organización",
                    controller: _entidadController,
                    hint: "Ej. Parques Nacionales Naturales de Colombia",
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: "Cargo / Rol Descriptivo",
                    controller: _cargoRolController,
                    hint: "Ej. Bióloga de campo / Guardabosques",
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: "Municipio de residencia",
                    controller: _municipioController,
                    hint: "Ej. Riofrío / Trujillo / Tuluá",
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Sobre mí con contador de caracteres
              _buildSectionCard(
                title: "Biografía y Perfil",
                icon: Icons.notes_rounded,
                children: [
                  TextFormField(
                    controller: _sobreMiController,
                    maxLines: 4,
                    maxLength: 300,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                    decoration: InputDecoration(
                      labelText: "Sobre mí",
                      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      hintText: "Cuéntanos sobre tu labor de monitoreo, especialidad o intereses en el PNR Páramo del Duende...",
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
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
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. Botón guardar cambios
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5E3A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Guardar cambios",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
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
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1E5E3A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3A22),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? prefixIcon,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: TextStyle(
        fontSize: 14,
        color: readOnly ? const Color(0xFF6B7280) : const Color(0xFF111827),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
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
          borderSide: BorderSide(
            color: readOnly ? const Color(0xFFE5E7EB) : const Color(0xFF1E5E3A),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}