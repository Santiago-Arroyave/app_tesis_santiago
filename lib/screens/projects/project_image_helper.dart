import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/api_connection/api_config.dart';

/// Helper centralizado para resolver la imagen de portada de un proyecto
/// tanto en las tarjetas de listado como en la cabecera de `ProjectDetailScreen`.
class ProjectImageHelper {
  static final Map<int, String> _projectCoverCache = {};
  static final Map<int, Map<String, dynamic>> _reportCache = {};

  /// Extrae la URL de imagen siguiendo exactamente la misma prioridad en toda la app:
  /// 1. Si el proyecto tiene `imagenUrl` / `fotoPortada` directa, la usa.
  /// 2. Si no, toma la foto principal del primer reporte asociado (`proyecto.reportes.first.fotoPrincipalUrl`).
  /// 3. Si ya fue resuelta previamente en caché para ese `projectId`, la retorna.
  static String resolveImageUrl(
    dynamic project, {
    List<dynamic>? extraReportes,
  }) {
    if (project is! Map) return '';

    // 1. Campos directos del proyecto (imagenUrl / fotoPortada)
    final directImg = project['imagenUrl'] ??
        project['fotoPortada'] ??
        project['fotoPrincipalUrl'] ??
        project['fotoUrl'] ??
        project['imageUrl'] ??
        project['foto'];
    if (directImg != null) {
      final str = directImg.toString().trim();
      if (str.isNotEmpty &&
          (str.startsWith('http://') || str.startsWith('https://'))) {
        return str;
      }
    }

    // 2. Foto principal del reporte asociado (proyecto.reportes.first.fotoPrincipalUrl)
    final List<dynamic> candidateLists = [
      if (project['reportes'] is List) ...(project['reportes'] as List),
      if (project['reportesAsociados'] is List)
        ...(project['reportesAsociados'] as List),
      ...?extraReportes,
    ];

    for (final item in candidateLists) {
      final url = _extractPhotoFromReportMap(item);
      if (url.isNotEmpty) {
        return url;
      }
    }

    // 3. Caché en memoria por ID de proyecto
    final int? projectId = _parseId(project['id'] ?? project['idProyecto']);
    if (projectId != null && _projectCoverCache.containsKey(projectId)) {
      return _projectCoverCache[projectId]!;
    }

    return '';
  }

  static String _extractPhotoFromReportMap(dynamic item) {
    if (item is! Map) return '';
    final Map rep = item['reporte'] is Map ? item['reporte'] as Map : item;

    final repImg = rep['fotoPrincipalUrl'] ??
        rep['imagenUrl'] ??
        rep['fotoUrl'] ??
        rep['urlFoto'] ??
        rep['foto'];
    if (repImg != null) {
      final str = repImg.toString().trim();
      if (str.isNotEmpty &&
          (str.startsWith('http://') || str.startsWith('https://'))) {
        return str;
      }
    }

    final evs = rep['evidencias'];
    if (evs is List && evs.isNotEmpty && evs.first is Map) {
      final evUrl = evs.first['urlArchivo'] ?? evs.first['url'];
      if (evUrl != null) {
        final str = evUrl.toString().trim();
        if (str.isNotEmpty &&
            (str.startsWith('http://') || str.startsWith('https://'))) {
          return str;
        }
      }
    }

    return '';
  }

  static int? _parseId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw != null) return int.tryParse(raw.toString());
    return null;
  }

  /// Registra en caché la URL resuelta para un proyecto.
  static void cacheProjectImage(int projectId, String url) {
    if (projectId > 0 && url.trim().isNotEmpty) {
      _projectCoverCache[projectId] = url.trim();
    }
  }

  /// Enriquece una lista de proyectos obteniendo el primer reporte asociado
  /// (`proyecto.reportes.first.fotoPrincipalUrl`) cuando el endpoint de listado
  /// (`GET /api/proyectos`) no incluye la relación `reportes` en el DTO resumido.
  static Future<void> enrichProjectsWithReportImages(
    List<dynamic> projects, {
    String? token,
  }) async {
    final List<Map> pendingProjects = [];

    for (final p in projects) {
      if (p is Map) {
        final existing = resolveImageUrl(p);
        if (existing.isNotEmpty) {
          p['imagenUrl'] ??= existing;
          final pId = _parseId(p['id']);
          if (pId != null) cacheProjectImage(pId, existing);
        } else {
          pendingProjects.add(p);
        }
      }
    }

    if (pendingProjects.isEmpty) return;

    await Future.wait(
      pendingProjects.map((p) => _resolveSingleProjectReportImage(p, token)),
    );
  }

  static Future<void> _resolveSingleProjectReportImage(
    Map project,
    String? token,
  ) async {
    final int? projectId = _parseId(project['id'] ?? project['idProyecto']);
    if (projectId == null || projectId <= 0) return;

    if (_projectCoverCache.containsKey(projectId)) {
      final cachedUrl = _projectCoverCache[projectId]!;
      project['imagenUrl'] = cachedUrl;
      return;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    try {
      // 1. Obtener reportes asociados al proyecto
      List<dynamic> asociados = [];
      if (project['reportes'] is List &&
          (project['reportes'] as List).isNotEmpty) {
        asociados = project['reportes'] as List;
      } else if (project['reportesAsociados'] is List &&
          (project['reportesAsociados'] as List).isNotEmpty) {
        asociados = project['reportesAsociados'] as List;
      } else {
        final vincRes = await http
            .get(
              Uri.parse(
                '${ApiConfig.baseUrl}/api/proyecto-reportes/proyecto/$projectId',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12));

        if (vincRes.statusCode == 200) {
          final vincBody = jsonDecode(vincRes.body);
          if (vincBody is List) {
            asociados = vincBody;
          } else if (vincBody is Map && vincBody['content'] is List) {
            asociados = vincBody['content'] as List;
          }
        }
      }

      if (asociados.isEmpty) {
        final detRes = await http
            .get(
              Uri.parse(
                '${ApiConfig.baseUrl}/api/proyectos/$projectId/detalle-completo',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12));
        if (detRes.statusCode == 200) {
          final detBody = jsonDecode(detRes.body);
          if (detBody is Map) {
            final projMap = detBody['proyecto'] is Map
                ? detBody['proyecto'] as Map
                : detBody;
            final directProjImg = resolveImageUrl(projMap);
            if (directProjImg.isNotEmpty) {
              project['imagenUrl'] = directProjImg;
              cacheProjectImage(projectId, directProjImg);
              return;
            }
            final rawAsoc = detBody['reportesAsociados'] ??
                detBody['reportes'] ??
                projMap['reportesAsociados'] ??
                projMap['reportes'];
            if (rawAsoc is List) {
              asociados = rawAsoc;
            }
          }
        }
      }

      if (asociados.isEmpty) return;

      // Revisar si el objeto asociado ya trae fotoPrincipalUrl directamente
      for (final item in asociados) {
        final directPhoto = _extractPhotoFromReportMap(item);
        if (directPhoto.isNotEmpty) {
          project['reportes'] = asociados;
          project['imagenUrl'] = directPhoto;
          cacheProjectImage(projectId, directPhoto);
          return;
        }
      }

      // 2. Consultar los reportes asociados por su reporteId (igual que en ProjectDetailScreen)
      for (final item in asociados) {
        if (item is! Map) continue;

        final int? repId = _parseId(
          item['reporteId'] ?? item['idReporte'] ?? item['id'],
        );
        if (repId == null || repId <= 0) continue;

        Map<String, dynamic>? repData = _reportCache[repId];
        if (repData == null) {
          final repRes = await http
              .get(
                Uri.parse('${ApiConfig.baseUrl}/api/reportes/$repId'),
                headers: headers,
              )
              .timeout(const Duration(seconds: 12));

          if (repRes.statusCode == 200) {
            final decoded = jsonDecode(repRes.body);
            if (decoded is Map<String, dynamic>) {
              repData = decoded;
              _reportCache[repId] = repData;
            }
          }
        }

        if (repData != null) {
          final fotoUrl = _extractPhotoFromReportMap(repData);
          if (fotoUrl.isNotEmpty) {
            project['reportes'] = [repData];
            project['imagenUrl'] = fotoUrl;
            cacheProjectImage(projectId, fotoUrl);
            return;
          }
        }
      }
    } catch (_) {}
  }
}
