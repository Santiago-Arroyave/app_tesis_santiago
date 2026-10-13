import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';

class ReportService {
  static const _baseUrl = ApiConfig.baseUrl;

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
        final body = jsonDecode(response.body);
        if (body is List) return body;
        if (body is Map && body['content'] is List) {
          return body['content'] as List;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Obtener reportes del usuario autenticado (GET /api/reportes/mis-reportes) ─
  static Future<List<dynamic>> getMisReportes() async {
    try {
      final headers = await _authHeaders();
      final currentUserId = await AuthStorage.getUserId();
      final userData = await AuthStorage.getUserData();
      final currentUserEmail =
          (userData?['correo'] ?? userData?['email'] ?? await AuthStorage.getEmail())
              ?.toString()
              .trim()
              .toLowerCase();

      bool belongsToCurrentUser(dynamic r) {
        if (r is! Map) return false;
        final repUserId = r['usuarioId'] ??
            r['idUsuario'] ??
            r['creadoPorId'] ??
            (r['usuario'] is Map ? r['usuario']['id'] : null);
        if (currentUserId != null && repUserId != null) {
          return repUserId.toString() == currentUserId.toString();
        }
        final repEmail = (r['usuarioCorreo'] ??
                r['correoUsuario'] ??
                (r['usuario'] is Map
                    ? (r['usuario']['correo'] ?? r['usuario']['email'])
                    : null))
            ?.toString()
            .trim()
            .toLowerCase();
        if (currentUserEmail != null &&
            currentUserEmail.isNotEmpty &&
            repEmail != null &&
            repEmail.isNotEmpty) {
          return repEmail == currentUserEmail;
        }
        return false;
      }

      // 1. Intentar endpoint dedicado GET /api/reportes/mis-reportes
      try {
        final myRes = await http
            .get(
              Uri.parse('$_baseUrl/api/reportes/mis-reportes'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 25));

        if (myRes.statusCode == 200) {
          final body = jsonDecode(myRes.body);
          List<dynamic> list = [];
          if (body is List) {
            list = body;
          } else if (body is Map && body['content'] is List) {
            list = body['content'] as List;
          }
          // Si los objetos traen usuarioId/usuarioCorreo, asegurar que coincidan con el usuario actual
          return list.where((r) {
            if (r is Map &&
                (r['usuarioId'] != null ||
                    r['idUsuario'] != null ||
                    r['usuarioCorreo'] != null ||
                    r['usuario'] != null)) {
              return belongsToCurrentUser(r);
            }
            return true;
          }).toList();
        }
      } catch (_) {}

      // 2. Fallback: consultar GET /api/reportes y filtrar localmente por usuarioId == AuthStorage.getUserId()
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/reportes?page=0&size=200'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> data = [];
        if (body is List) {
          data = body;
        } else if (body is Map && body['content'] is List) {
          data = body['content'] as List;
        }
        return data.where(belongsToCurrentUser).toList();
      }
      return [];
    } catch (_) {
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
    String? sector,
    Map<String, dynamic>? datosEspecificos,
    String? fotoPrincipalUrl,
    bool publico = true,
  }) async {
    try {
      final headers = await _authHeaders();
      final payload = <String, dynamic>{
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
      };
      if (sector != null) {
        payload['sector'] = sector;
      }
      if (datosEspecificos != null) {
        payload['datosEspecificos'] = jsonEncode(datosEspecificos);
      }
      final body = jsonEncode(payload);

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

  // ── Actualizar reporte (PUT /api/reportes/{id}) ───────────
  static Future<ReportResult> updateReporte({
    required dynamic id,
    required Map<String, dynamic> body,
    List<int>? evidenciasEliminadasIds,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.trim().isEmpty) {
        return ReportResult.error(
          'Sesión no encontrada o expirada. Por favor inicia sesión nuevamente.',
        );
      }

      final cleanToken = token.trim().startsWith('Bearer ')
          ? token.trim().substring(7).trim()
          : token.trim();

      final payload = Map<String, dynamic>.from(body);
      if (evidenciasEliminadasIds != null && evidenciasEliminadasIds.isNotEmpty) {
        final List<Map<String, dynamic>> evidenciasPayload = [];
        if (payload['evidencias'] is List) {
          for (final item in (payload['evidencias'] as List)) {
            if (item is Map) {
              evidenciasPayload.add(Map<String, dynamic>.from(item));
            }
          }
        }
        for (final idEliminado in evidenciasEliminadasIds) {
          final alreadyAdded = evidenciasPayload.any(
            (e) => e['id'] == idEliminado && e['eliminar'] == true,
          );
          if (!alreadyAdded) {
            evidenciasPayload.add({
              'id': idEliminado,
              'eliminar': true,
              'tipoArchivo': 'imagen',
            });
          }
        }
        payload['evidencias'] = evidenciasPayload;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/api/reportes/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cleanToken',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : payload;
        return ReportResult.success(
          decoded is Map<String, dynamic> ? decoded : payload,
        );
      } else {
        String errMsg = 'Error al actualizar reporte (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          if (data is Map) {
            errMsg = (data['message'] ?? data['error'] ?? errMsg).toString();
          }
        } catch (_) {}
        return ReportResult.error(errMsg);
      }
    } catch (e) {
      return ReportResult.error('Error de conexión al actualizar reporte: $e');
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

