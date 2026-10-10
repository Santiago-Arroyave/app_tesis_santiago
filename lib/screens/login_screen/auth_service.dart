import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:goblink_park/screens/api_connection/api_config.dart';

class AuthService {
  //static const _baseUrl = 'http://10.0.2.2:8080'; // localhost en emulador Android
  static const _baseUrl = ApiConfig.baseUrl; // URL de producción
  static final _storage = const FlutterSecureStorage();

  // ── Guardar / leer / borrar token ─────────────────────────
  static Future<void> saveToken(String token) async =>
      await _storage.write(key: 'jwt_token', value: token);

  static Future<String?> getToken() async =>
      await _storage.read(key: 'jwt_token');

  static Future<void> deleteToken() async =>
      await _storage.delete(key: 'jwt_token');

  static Future<void> saveUserId(int id) async =>
      await _storage.write(key: 'user_id', value: id.toString());

  static Future<int?> getUserId() async {
    final id = await _storage.read(key: 'user_id');
    return id != null ? int.tryParse(id) : null;
  }

  static Future<void> deleteUserId() async =>
      await _storage.delete(key: 'user_id');

  // ── Guardar / leer datos del usuario ──────────────────────
static Future<void> saveUserData(Map<String, dynamic> usuario) async =>
    await _storage.write(key: 'user_data', value: jsonEncode(usuario));

static Future<Map<String, dynamic>?> getUserData() async {
  final data = await _storage.read(key: 'user_data');
  return data != null ? jsonDecode(data) as Map<String, dynamic> : null;
}

static Future<void> deleteUserData() async =>
    await _storage.delete(key: 'user_data');

  // ── Registro ──────────────────────────────────────────────
  static Future<AuthResult> register({
    required String nombres,
    required String correo,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombres': nombres,
          'correo': correo,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await saveToken(data['token']);
        await saveUserId(data['usuario']['id'] as int);
        await saveUserData(data['usuario']);
        return AuthResult.success(data['token'], data['usuario']);
      } else {
        return AuthResult.error(data['message'] ?? 'Error al registrarse');
      }
    } catch (e) {
      return AuthResult.error('Error de conexión: $e');
    }
  }

  // ── Login ─────────────────────────────────────────────────
  static Future<AuthResult> login({
    required String correo,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/login');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': correo, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = null;
      }

      debugPrint('>>> Status login: ${response.statusCode}');

      if (response.statusCode == 200 && data != null && data['token'] != null) {
        debugPrint('>>> Token recibido: ${data['token']}');
        await saveToken(data['token'] as String);
        if (data['usuario'] != null && data['usuario']['id'] != null) {
          await saveUserId(data['usuario']['id'] as int);
          await saveUserData(data['usuario'] as Map<String, dynamic>);
        }
        final savedToken = await getToken();
        debugPrint('>>> Token guardado: $savedToken');

        return AuthResult.success(
          data['token'] as String,
          (data['usuario'] as Map<String, dynamic>?) ?? {},
        );
      } else {
        String errorMessage = 'Contraseña o usuario incorrectos';
        if (data != null) {
          final serverMsg = data['message'] ?? data['error'];
          if (serverMsg != null) {
            final str = serverMsg.toString().trim();
            final lower = str.toLowerCase();
            if (lower.contains('credenciales') ||
                lower.contains('invalida') ||
                lower.contains('inválida') ||
                lower.contains('password') ||
                lower.contains('contraseña') ||
                lower.contains('incorrect') ||
                response.statusCode == 401 ||
                response.statusCode == 400) {
              errorMessage = 'Contraseña o usuario incorrectos';
            } else if (str.isNotEmpty) {
              errorMessage = str;
            }
          }
        }
        return AuthResult.error(errorMessage);
      }
    } on TimeoutException {
      return AuthResult.error('Tiempo de espera agotado');
    } on SocketException {
      return AuthResult.error('Error de conexión con el servidor');
    } catch (e) {
      return AuthResult.error('Error de conexión: $e');
    }
  }

  /*static Future<AuthResult> login({
    required String correo,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': correo,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveToken(data['token']);
        return AuthResult.success(data['token'], data['usuario']);
      } else {
        return AuthResult.error(
            data['message'] ?? 'Credenciales incorrectas');
      }
    } catch (e) {
      return AuthResult.error('Error de conexión: $e');
    }
  }*/
}

// ── Modelo de resultado ────────────────────────────────────
class AuthResult {
  final bool success;
  final String? token;
  final Map<String, dynamic>? usuario;
  final String? errorMessage;

  AuthResult._({
    required this.success,
    this.token,
    this.usuario,
    this.errorMessage,
  });

  factory AuthResult.success(String token, Map<String, dynamic> usuario) =>
      AuthResult._(success: true, token: token, usuario: usuario);

  factory AuthResult.error(String message) =>
      AuthResult._(success: false, errorMessage: message);
}
