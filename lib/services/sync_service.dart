import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/services/local_database_service.dart';
import 'package:goblink_park/services/supabase_storage_service.dart';

class SyncResult {
  final int syncedCount;
  final int failedCount;
  final int remainingCount;

  const SyncResult({
    required this.syncedCount,
    required this.failedCount,
    required this.remainingCount,
  });
}

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  static const String _baseUrl = ApiConfig.baseUrl;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  /// Notificadores reactivos para actualizar banners y listas en UI ("Mis reportes")
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  final StreamController<SyncResult> _onSyncCompletedController =
      StreamController<SyncResult>.broadcast();

  Stream<SyncResult> get onSyncCompleted => _onSyncCompletedController.stream;

  /// Inicializa el listener reactivo de conectividad y actualiza el conteo inicial
  Future<void> initialize() async {
    await refreshPendingCount();

    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasNet = _containsActiveConnection(results);
      if (hasNet) {
        debugPrint(
          '>>> [SyncService] Conexión detectada ($results). Iniciando sincronización automática...',
        );
        await syncPendingReports();
      }
    });

    // Si al iniciar ya hay conexión y existen reportes pendientes, sincronizar en segundo plano
    if (await hasInternetConnection()) {
      final count = await LocalDatabaseService.instance.getPendingCount();
      if (count > 0) {
        unawaited(syncPendingReports());
      }
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  static bool _containsActiveConnection(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet) ||
        results.contains(ConnectivityResult.vpn);
  }

  /// Comprueba si el dispositivo tiene conectividad activa (Wi-Fi o Datos móviles)
  static Future<bool> hasInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _containsActiveConnection(results);
    } catch (_) {
      return false;
    }
  }

  /// Actualiza el contador reactivo de reportes pendientes en SQLite
  Future<int> refreshPendingCount() async {
    try {
      final count = await LocalDatabaseService.instance.getPendingCount();
      pendingCountNotifier.value = count;
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _resolveCategoriaId(String categoryName, String token) async {
    final c = categoryName.trim().toLowerCase();
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/categorias'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List) {
          for (final item in list) {
            final nom = (item['nombre'] ?? '').toString().toLowerCase();
            if (nom.contains(c) || c.contains(nom)) {
              return (item['id'] as num).toInt();
            }
          }
          if (list.isNotEmpty && list.first['id'] != null) {
            return (list.first['id'] as num).toInt();
          }
        }
      }
    } catch (_) {}

    if (c.contains('fauna')) return 2;
    if (c.contains('agua')) return 3;
    if (c.contains('suelo')) return 4;
    if (c.contains('aire')) return 5;
    return 1; // Flora
  }

  Future<int> _resolvePrioridadId(String priorityName, String token) async {
    final p = priorityName.trim().toLowerCase();
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/prioridades'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List) {
          for (final item in list) {
            final nom = (item['nombre'] ?? '').toString().toLowerCase();
            if (nom.contains(p) || p.contains(nom)) {
              return (item['id'] as num).toInt();
            }
          }
          if (list.isNotEmpty && list.first['id'] != null) {
            return (list.first['id'] as num).toInt();
          }
        }
      }
    } catch (_) {}

    if (p.contains('alta')) return 1;
    if (p.contains('baja')) return 3;
    return 2; // Media
  }

  /// Sincroniza secuencialmente todos los reportes pendientes en `reportes_offline`
  Future<SyncResult> syncPendingReports() async {
    if (_isSyncing) {
      final rem = await refreshPendingCount();
      return SyncResult(syncedCount: 0, failedCount: 0, remainingCount: rem);
    }

    final connected = await hasInternetConnection();
    if (!connected) {
      final rem = await refreshPendingCount();
      return SyncResult(syncedCount: 0, failedCount: 0, remainingCount: rem);
    }

    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      final rem = await refreshPendingCount();
      return SyncResult(syncedCount: 0, failedCount: 0, remainingCount: rem);
    }

    _isSyncing = true;
    isSyncingNotifier.value = true;

    int synced = 0;
    int failed = 0;

    try {
      final pendingList = await LocalDatabaseService.instance.getPendingReports(
        includeError: true,
      );

      for (final row in pendingList) {
        final int id = (row['id'] as num).toInt();
        final int currentRetries = ((row['reintentos'] ?? 0) as num).toInt();

        await LocalDatabaseService.instance.updateSyncStatus(
          id: id,
          estadoSincronizacion: 'SUBIENDO',
        );

        final bool ok = await _uploadSingleOfflineReport(row, token);
        if (ok) {
          await LocalDatabaseService.instance.deleteOfflineReport(id);
          synced++;
        } else {
          failed++;
          await LocalDatabaseService.instance.updateSyncStatus(
            id: id,
            estadoSincronizacion: 'PENDIENTE',
            reintentos: currentRetries + 1,
          );
        }
      }
    } catch (e) {
      debugPrint('>>> [SyncService] Error general sincronizando cola: $e');
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
    }

    final remaining = await refreshPendingCount();
    final result = SyncResult(
      syncedCount: synced,
      failedCount: failed,
      remainingCount: remaining,
    );
    _onSyncCompletedController.add(result);
    return result;
  }

  Future<bool> _uploadSingleOfflineReport(
    Map<String, dynamic> row,
    String token,
  ) async {
    try {
      final String clientUuid = (row['client_uuid'] ?? '').toString();
      final String titulo = (row['titulo'] ?? 'Reporte de campo').toString();
      final String categoria = (row['categoria'] ?? 'Flora').toString();
      final String prioridad = (row['prioridad'] ?? 'Media').toString();
      final String descripcion = (row['descripcion'] ?? '').toString();
      final double latitud = ((row['latitud'] ?? 4.08) as num).toDouble();
      final double longitud = ((row['longitud'] ?? -76.52) as num).toDouble();
      final String fotoRutaLocal = (row['foto_ruta_local'] ?? '').toString();
      final String fechaCreacion =
          (row['fecha_creacion'] ?? DateTime.now().toIso8601String()).toString();
      final String sector =
          (row['sector'] ?? 'Sector Páramo del Duende').toString();
      final String municipio =
          (row['municipio'] ?? 'Páramo del Duende').toString();

      Map<String, dynamic> datosEspecificos = {};
      final rawDatos = (row['datos_especificos'] ?? '').toString().trim();
      if (rawDatos.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawDatos);
          if (decoded is Map<String, dynamic>) {
            datosEspecificos = decoded;
          }
        } catch (_) {}
      }

      // Reunir todas las rutas locales de fotos del reporte
      final List<String> localPhotoPaths = [];
      if (fotoRutaLocal.isNotEmpty) {
        localPhotoPaths.add(fotoRutaLocal);
      }
      final rawExtraPhotos = (row['fotos_adicionales'] ?? '').toString().trim();
      if (rawExtraPhotos.isNotEmpty) {
        try {
          final decodedList = jsonDecode(rawExtraPhotos);
          if (decodedList is List) {
            for (final pStr in decodedList) {
              final s = pStr.toString().trim();
              if (s.isNotEmpty && !localPhotoPaths.contains(s)) {
                localPhotoPaths.add(s);
              }
            }
          }
        } catch (_) {}
      }

      final catId = await _resolveCategoriaId(categoria, token);
      final prioId = await _resolvePrioridadId(prioridad, token);

      // 1. Subir fotografías a Supabase Storage para obtener URLs públicas
      final List<String> uploadedUrls = [];
      for (final path in localPhotoPaths) {
        final file = File(path);
        if (await file.exists()) {
          final url = await SupabaseStorageService.uploadReportImage(file);
          if (url != null && url.isNotEmpty) {
            uploadedUrls.add(url);
          }
        }
      }

      // 2. Si todas las fotos subieron a Supabase (o el reporte no tenía fotos), enviar JSON a POST /api/reportes incluyendo clientUuid
      if (uploadedUrls.isNotEmpty || localPhotoPaths.isEmpty) {
        final List<Map<String, dynamic>> evidenciasJson = [];
        for (int i = 0; i < uploadedUrls.length; i++) {
          final u = uploadedUrls[i];
          evidenciasJson.add({
            'urlArchivo': u,
            'tipoArchivo': 'imagen',
            'nombreArchivo': u.split('/').last,
            'mimeType': 'image/jpeg',
            'descripcion': titulo,
            'esPrincipal': i == 0,
          });
        }

        final payload = <String, dynamic>{
          'clientUuid': clientUuid,
          'titulo': titulo,
          'descripcion': descripcion,
          'categoriaId': catId,
          'prioridadId': prioId,
          'latitud': latitud,
          'longitud': longitud,
          'direccionReferencia': '$sector, $municipio',
          'sector': sector,
          'fuente': 'mobile',
          'fechaEvento': fechaCreacion,
          'publico': true,
          'estado': true,
          if (uploadedUrls.isNotEmpty) 'fotoPrincipalUrl': uploadedUrls.first,
          if (evidenciasJson.isNotEmpty) 'evidencias': evidenciasJson,
          if (datosEspecificos.isNotEmpty) 'datosEspecificos': datosEspecificos,
        };

        final jsonRes = await http
            .post(
              Uri.parse('$_baseUrl/api/reportes'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 35));

        if (jsonRes.statusCode == 200 || jsonRes.statusCode == 201) {
          return true;
        }
      }

      // 3. Fallback: Envío Multipart directo a POST /api/reportes incluyendo clientUuid y archivos locales
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/reportes'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['clientUuid'] = clientUuid;
      request.fields['titulo'] = titulo;
      request.fields['descripcion'] = descripcion;
      request.fields['categoriaId'] = catId.toString();
      request.fields['prioridadId'] = prioId.toString();
      request.fields['latitud'] = latitud.toString();
      request.fields['longitud'] = longitud.toString();
      request.fields['direccionReferencia'] = '$sector, $municipio';
      request.fields['sector'] = sector;
      request.fields['municipio'] = municipio;
      request.fields['fuente'] = 'mobile';
      if (datosEspecificos.isNotEmpty) {
        request.fields['datosEspecificos'] = jsonEncode(datosEspecificos);
      }

      for (final path in localPhotoPaths) {
        final file = File(path);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'evidencias',
              file.path,
              filename: file.path.split(Platform.isWindows ? '\\' : '/').last,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }
      }

      final streamedRes =
          await request.send().timeout(const Duration(seconds: 45));
      final multipartRes = await http.Response.fromStream(streamedRes);

      return multipartRes.statusCode == 200 || multipartRes.statusCode == 201;
    } catch (e) {
      debugPrint('>>> [SyncService] Error subiendo reporte offline: $e');
      return false;
    }
  }
}
