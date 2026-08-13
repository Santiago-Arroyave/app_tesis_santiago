import 'package:flutter/material.dart';
import 'package:app_tesis/screens/profile/edit_profile_screen.dart';
import 'package:app_tesis/screens/profile/notifications_screen.dart';
import 'package:app_tesis/screens/login_screen/login_screen.dart';

import 'dart:convert';
import 'dart:io';
//import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:app_tesis/screens/login_screen/auth_service.dart';
//import 'package:app_tesis/screens/login_screen/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _baseUrl = 'http://10.0.2.2:8080';

  Map<String, dynamic>? _usuario;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── Cargar perfil ──────────────────────────────────────────

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await AuthService.getToken();
      final id = await AuthService.getUserId();

      if (id == null) {
        final localData = await AuthService.getUserData();
        if (localData != null) {
          setState(() {
            _usuario = localData;
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _errorMessage = 'No se encontró el ID del usuario';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/usuarios/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await AuthService.saveUserData(data);
        setState(() {
          _usuario = data;
          _isLoading = false;
        });
      } else {
        // 403 u otro error → usar datos guardados del login
        final localData = await AuthService.getUserData();
        if (localData != null) {
          setState(() {
            _usuario = localData;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Error al cargar perfil';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      final localData = await AuthService.getUserData();
      if (localData != null && mounted) {
        setState(() {
          _usuario = localData;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAvatar() {
    final foto = _usuario?['fotoPerfil'];

    if (foto == null || foto.toString().trim().isEmpty) {
      return Icon(Icons.person, size: 50, color: Colors.grey.shade600);
    }

    try {
      final texto = foto.toString();

      // URL
      if (texto.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            texto,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      }

      // Base64 con encabezado
      if (texto.startsWith('data:image')) {
        final bytes = base64Decode(texto.split(',').last);

        return ClipOval(
          child: Image.memory(
            bytes,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      }

      // Base64 puro (el que devuelve tu backend)
      final bytes = base64Decode(texto);

      return ClipOval(
        child: Image.memory(bytes, width: 100, height: 100, fit: BoxFit.cover),
      );
    } catch (_) {
      return Icon(Icons.person, size: 50, color: Colors.grey.shade600);
    }
  }

  /*Widget _buildAvatar() {
    final foto = _usuario?['fotoPerfil'];

    // Sin foto → ícono por defecto
    if (foto == null || foto.toString().isEmpty) {
      return Icon(Icons.person, size: 50, color: Colors.grey.shade600);
    }

    // Base64
    if (foto.toString().startsWith('data:image')) {
      try {
        final base64Str = foto.toString().split(',').last;
        final bytes = base64Decode(base64Str);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        return Icon(Icons.person, size: 50, color: Colors.grey.shade600);
      }
    }

    // URL normal
    if (foto.toString().startsWith('http')) {
      return ClipOval(
        child: Image.network(
          foto,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.person, size: 50, color: Colors.grey.shade600),
        ),
      );
    }

    // Cualquier otro caso
    return Icon(Icons.person, size: 50, color: Colors.grey.shade600);
  }*/

  /*Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await AuthService.getToken();
      final id = await AuthService.getUserId();
      if (id == null) {
        setState(() {
          _errorMessage = 'No se encontró el ID del usuario';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/usuarios/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('ID: $id');
      debugPrint('TOKEN: $token');
      debugPrint('STATUS: ${response.statusCode}');
      debugPrint('BODY: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _usuario = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error al cargar perfil';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }*/

  // ── Editar nombre ──────────────────────────────────────────
  Future<void> _editName() async {
    final controller = TextEditingController(text: _usuario?['nombres'] ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Escribe tu nombre'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 7, 83, 11),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Guardar solo localmente
    final nuevoNombre = controller.text.trim();
    if (nuevoNombre.isEmpty) return;

    /*setState(() {
      _usuario = {..._usuario!, 'nombres': nuevoNombre};
    });

    // Actualizar datos locales guardados
    await AuthService.saveUserData(_usuario!);*/
    await _updateUser(nombres: nuevoNombre);

    /*if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre actualizado'),
          backgroundColor: Colors.green,
        ),
      );
    }*/
  }
  /*Future<void> _editName() async {
    final controller = TextEditingController(text: _usuario?['nombres'] ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Escribe tu nombre'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _updateUser(nombres: controller.text.trim());
  }*/

  // ── Editar foto ────────────────────────────────────────────
  Future<void> _editPhoto() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color.fromARGB(255, 7, 83, 11)),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked == null || !mounted) return;

    // Convertir a Base64
    final file = File(picked.path);

    await _updateUser(foto: file);
  }

  // ── Eliminar foto ──────────────────────────────────────────
  /*Future<void> _deletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red.shade600, size: 56),
            const SizedBox(height: 12),
            const Text(
              '¿Quieres eliminar esta imagen?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _updateUser(fotoPerfil: '');
  }*/

  // ── Actualizar usuario PUT /api/usuarios/{id} ──────────────
  Future<void> _updateUser({String? nombres, File? foto}) async {
    try {
      final token = await AuthService.getToken();

      var request = http.MultipartRequest(
        "PUT",
        Uri.parse("$_baseUrl/api/usuarios/perfil"),
      );

      request.headers["Authorization"] = "Bearer $token";

      request.fields["nombres"] = nombres ?? (_usuario?["nombres"] ?? "");

      request.fields["username"] = _usuario?["username"] ?? "";

      request.fields["telefono"] = _usuario?["telefono"] ?? "";

      if (foto != null) {
        request.files.add(
          await http.MultipartFile.fromPath("fotoPerfil", foto.path),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        await _loadProfile();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Perfil actualizado"),
            backgroundColor: Color.fromARGB(255, 7, 83, 11),
          ),
        );
      } else {
        if (!mounted) return;

        final body = await response.stream.bytesToString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /*Future<void> _updateUser({String? nombres, String? fotoPerfil}) async {
    try {
      final token = await AuthService.getToken();
      final id = await AuthService.getUserId();

      final body = {
        'nombres': nombres ?? _usuario?['nombres'],
        'correo': _usuario?['correo'],
        'username': _usuario?['username'],
        'telefono': _usuario?['telefono'],
        'fotoPerfil': fotoPerfil ?? _usuario?['fotoPerfil'],
        'estado': _usuario?['estado'] ?? true,
        'rolId': _usuario?['rolId'] ?? 1,
      };

      final response = await http.put(
        Uri.parse('$_baseUrl/api/usuarios/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      debugPrint('PUT usuario: $id');
      debugPrint('STATUS PUT: ${response.statusCode}');
      debugPrint('BODY PUT: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _loadProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Error al actualizar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }*/

  // ── Cerrar sesión ──────────────────────────────────────────
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout, color: Colors.red.shade600, size: 48),
            const SizedBox(height: 12),
            const Text(
              '¿Quieres cerrar sesión?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await AuthService.deleteToken();
    await AuthService.deleteUserId();
    await AuthService.deleteUserData();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // ── Avatar ───────────────────────────
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: _editPhoto,

                        child: CircleAvatar(
                          radius: 50,

                          backgroundColor: Colors.grey.shade300,

                          child: _buildAvatar(),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _editPhoto,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      /* Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),*/
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Nombre debajo del avatar ──────────
                  Text(
                    _usuario?['nombres'] ?? 'Sin nombre',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Lista de opciones ────────────────
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        children: [
                          // Nombre editable
                          _ProfileTile(
                            icon: Icons.person_outline,
                            title: 'Nombre',
                            subtitle: _usuario?['nombres'] ?? 'Sin nombre',
                            onTap: _editName,
                          ),
                          const Divider(),

                          // Notificaciones
                          _ProfileTile(
                            icon: Icons.notifications_none,
                            title: 'Notificaciones',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ),
                          ),
                          /*_ProfileTile(
                            icon: Icons.notifications_none,
                            title: 'Notificaciones',
                            onTap: () {},
                          ),
                          const Divider(),*/

                          // Cerrar sesión
                          _ProfileTile(
                            icon: Icons.logout,
                            title: 'Cerrar sesión',
                            iconColor: Colors.red.shade600,
                            textColor: Colors.red.shade600,
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // ── Avatar ───────────────────────────
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        child: _buildAvatar(),
                      ),
                      /*CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage:
                            _usuario?['fotoPerfil'] != null &&
                                _usuario!['fotoPerfil'].toString().isNotEmpty
                            ? NetworkImage(_usuario!['fotoPerfil'])
                            : null,
                        child:
                            _usuario?['fotoPerfil'] == null ||
                                _usuario!['fotoPerfil'].toString().isEmpty
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey.shade600,
                              )
                            : null,
                      ),*/
                      // Punto verde online
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Nombre debajo del avatar ──────────
                  Text(
                    _usuario?['nombres'] ?? 'Sin nombre',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _usuario?['correo'] ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 20),

                  // ── Lista de opciones ────────────────
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        children: [
                          // Nombre
                          _ProfileTile(
                            icon: Icons.person_outline,
                            title: 'Nombre',
                            subtitle: _usuario?['nombres'] ?? 'Sin nombre',
                            onTap: () {},
                          ),
                          const Divider(),

                          // Correo
                          _ProfileTile(
                            icon: Icons.email_outlined,
                            title: 'Correo',
                            subtitle: _usuario?['correo'] ?? 'Sin correo',
                            onTap: () {},
                          ),
                          const Divider(),

                          // Rol
                          _ProfileTile(
                            icon: Icons.badge_outlined,
                            title: 'Rol',
                            subtitle: _usuario?['rol'] ?? 'USER',
                            onTap: () {},
                          ),
                          const Divider(),

                          // Notificaciones
                          _ProfileTile(
                            icon: Icons.notifications_none,
                            title: 'Notificaciones',
                            onTap: () {},
                          ),
                          const Divider(),

                          // Cerrar sesión
                          _ProfileTile(
                            icon: Icons.logout,
                            title: 'Cerrar sesión',
                            iconColor: Colors.red.shade600,
                            textColor: Colors.red.shade600,
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }*/

  /* @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // ── Avatar ───────────────────────────
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: _editPhoto,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage:
                              _usuario?['fotoPerfil'] != null &&
                                  _usuario!['fotoPerfil'].toString().isNotEmpty
                              ? NetworkImage(_usuario!['fotoPerfil'])
                              : null,
                          child:
                              _usuario?['fotoPerfil'] == null ||
                                  _usuario!['fotoPerfil'].toString().isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey.shade600,
                                )
                              : null,
                        ),
                      ),
                      // Botón eliminar foto
                      if (_usuario?['fotoPerfil'] != null &&
                          _usuario!['fotoPerfil'].toString().isNotEmpty)
                        GestureDetector(
                          onTap: _deletePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Indicador online
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Lista de opciones ────────────────
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        children: [
                          // Nombre
                          _ProfileTile(
                            icon: Icons.person_outline,
                            title: 'Nombre',
                            subtitle: _usuario?['nombres'] ?? 'Sin nombre',
                            onTap: _editName,
                          ),
                          const Divider(),

                          // Notificaciones
                          _ProfileTile(
                            icon: Icons.notifications_none,
                            title: 'Notificaciones',
                            onTap: () {},
                          ),
                          const Divider(),

                          // Cerrar sesión
                          _ProfileTile(
                            icon: Icons.logout,
                            title: 'Cerrar sesión',
                            iconColor: Colors.red.shade600,
                            textColor: Colors.red.shade600,
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }*/
}

// ─── Tile de perfil ──────────────────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.grey.shade700),
      title: Text(title, style: TextStyle(color: textColor ?? Colors.black87)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/*
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Perfil")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage("https://via.placeholder.com/150"),
            ),
            const SizedBox(height: 10),
            const Text(
              "Usuario Demo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              child: const Text("Cambiar foto / nombre"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              child: const Text("Notificaciones"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Cerrar sesión"),
              onPressed: () {
                _cerrarSesion(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _cerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cerrar sesión"),
        content: const Text("¿Seguro que deseas salir?"),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Salir"),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
              //Navigator.pop(context);
              // aquí luego rediriges al login
            },
          ),
        ],
      ),
    );
  }
}*/
