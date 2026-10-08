import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:goblink_park/screens/api_connection/api_config.dart';

class AuthService {
  //static const _baseUrl = 'http://10.0.2.2:8080'; // localhost en emulador Android
  static const _baseUrl = '${ApiConfig.baseUrl}'; // URL de producción
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
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      debugPrint('>>> Status login: ${response.statusCode}');
      debugPrint('>>> Token recibido: ${data['token']}'); // ← agrega esto

      if (response.statusCode == 200) {
        await saveToken(data['token']);
        await saveUserId(data['usuario']['id'] as int);
        await saveUserData(data['usuario']);
        // Verifica que se guardó correctamente
        final savedToken = await getToken();
        debugPrint('>>> Token guardado: $savedToken'); // ← y esto

        return AuthResult.success(data['token'], data['usuario']);
      } else {
        return AuthResult.error(data['message'] ?? 'Credenciales incorrectas');
      }
    } on TimeoutException {
      return AuthResult.error('Tiempo de espera agotado.');
    } on SocketException {
      return AuthResult.error('No se pudo conectar al servidor.');
    } catch (e) {
      return AuthResult.error('Error: $e');
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
