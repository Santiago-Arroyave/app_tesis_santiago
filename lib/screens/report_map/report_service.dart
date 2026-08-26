import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_tesis/screens/login_screen/auth_service.dart';
import 'package:app_tesis/screens/api_connection/api_config.dart';

class ReportService {
  static const _baseUrl = '${ApiConfig.baseUrl}';

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Obtener todos los reportes ────────────────────────────
  static Future<List<dynamic>> getReportes() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/reportes'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Obtener categorías ────────────────────────────────────
  static Future<List<dynamic>> getCategorias() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/categorias'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Obtener prioridades ───────────────────────────────────
  static Future<List<dynamic>> getPrioridades() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/prioridades'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Obtener estados de reporte ────────────────────────────
  static Future<List<dynamic>> getEstadosReporte() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/estados-reporte'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Crear reporte ─────────────────────────────────────────
  static Future<ReportResult> createReporte({
    required int categoriaId,
    required int prioridadId,
    required int estadoReporteId,
    required String titulo,
    required String descripcion,
    required double latitud,
    required double longitud,
    String? direccionReferencia,
    String? fotoPrincipalUrl,
    bool publico = true,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = jsonEncode({
        'categoriaId': categoriaId,
        'prioridadId': prioridadId,
        'estadoReporteId': estadoReporteId,
        'titulo': titulo,
        'descripcion': descripcion,
        'fechaEvento': DateTime.now().toIso8601String(),
        'fuente': 'mobile',
        'latitud': latitud,
        'longitud': longitud,
        'direccionReferencia': direccionReferencia ?? '',
        'fotoPrincipalUrl': fotoPrincipalUrl ?? '',
        'publico': publico,
        'estado': true,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/api/reportes'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ReportResult.success(jsonDecode(response.body));
      } else {
        final data = jsonDecode(response.body);
        return ReportResult.error(data['message'] ?? 'Error al crear reporte');
      }
    } catch (e) {
      return ReportResult.error('Error de conexión: $e');
    }
  }
}

class ReportResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  ReportResult._({required this.success, this.data, this.errorMessage});

  factory ReportResult.success(Map<String, dynamic> data) =>
      ReportResult._(success: true, data: data);

  factory ReportResult.error(String message) =>
      ReportResult._(success: false, errorMessage: message);
}

