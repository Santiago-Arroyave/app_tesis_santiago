import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';

/// Servicio centralizado para la gestión del perfil de usuario y carga de fotos
class UserService {
  static const String _baseUrl = ApiConfig.baseUrl;

  /// Notificador reactivo global para sincronizar cambios de perfil/portada entre pantallas
  static final ValueNotifier<Map<String, dynamic>?> userNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Actualiza el estado global del usuario en memoria y almacenamiento local
  static Future<void> syncGlobalUser(Map<String, dynamic> userData) async {
    await AuthService.saveUserData(userData);
    userNotifier.value = Map<String, dynamic>.from(userData);
  }

  /// Obtiene los datos de perfil del usuario autenticado vía GET /api/usuarios/perfil
  static Future<Map<String, dynamic>?> obtenerPerfil() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return null;

    final cleanToken = token.trim().startsWith('Bearer ')
        ? token.trim().substring(7)
        : token.trim();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/usuarios/perfil'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cleanToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          await syncGlobalUser(data);
          return data;
        }
      }
    } catch (e) {
      debugPrint('Error en UserService.obtenerPerfil: $e');
    }
    return null;
  }

  /// Sube la foto de perfil (avatar) enviándola como MultipartFile 'fotoPerfil'
  static Future<Map<String, dynamic>?> subirFotoPerfil(File imageFile) async {
    return _actualizarFoto(campo: 'fotoPerfil', imageFile: imageFile);
  }

  /// Sube la foto de portada (banner) enviándola como MultipartFile 'fotoPortada'
  static Future<Map<String, dynamic>?> subirFotoPortada(File imageFile) async {
    return _actualizarFoto(campo: 'fotoPortada', imageFile: imageFile);
  }

  /// Petición multipart para actualizar fotos de usuario
  static Future<Map<String, dynamic>?> _actualizarFoto({
    required String campo,
    required File imageFile,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión no encontrada. Inicia sesión nuevamente.');
    }

    final cleanToken = token.trim().startsWith('Bearer ')
        ? token.trim().substring(7)
        : token.trim();

    final uri = Uri.parse('$_baseUrl/api/usuarios/perfil');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $cleanToken';

    // Adjuntar archivo en el campo exacto requerido por el backend
    request.files.add(
      await http.MultipartFile.fromPath(campo, imageFile.path),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final current = await AuthService.getUserData() ?? {};
        final merged = Map<String, dynamic>.from(current)..addAll(data);
        await syncGlobalUser(merged);
        return merged;
      }
    } else {
      String msg = 'Error ${response.statusCode} al actualizar $campo';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          msg = body['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }
    return null;
  }

  /// Elimina o restablece la foto de perfil
  static Future<Map<String, dynamic>?> eliminarFotoPerfil() async {
    return _eliminarFoto(campo: 'fotoPerfil');
  }

  /// Elimina o restablece la foto de portada
  static Future<Map<String, dynamic>?> eliminarFotoPortada() async {
    return _eliminarFoto(campo: 'fotoPortada');
  }

  static Future<Map<String, dynamic>?> _eliminarFoto({required String campo}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return null;

    final cleanToken = token.trim().startsWith('Bearer ')
        ? token.trim().substring(7)
        : token.trim();

    final uri = Uri.parse('$_baseUrl/api/usuarios/perfil');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $cleanToken';
    request.fields[campo] = '';

    final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final current = await AuthService.getUserData() ?? {};
        final merged = Map<String, dynamic>.from(current)..addAll(data);
        merged[campo] = '';
        merged['${campo}Url'] = '';
        if (campo == 'fotoPortada') {
          merged['foto_portada'] = '';
        } else if (campo == 'fotoPerfil') {
          merged['foto_perfil'] = '';
        }
        await syncGlobalUser(merged);
        return merged;
      }
    }
    return null;
  }
}
