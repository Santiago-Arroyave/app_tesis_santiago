import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goblink_park/models/app_notification.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/profile/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  static const _baseUrl = ApiConfig.baseUrl;
  static const _prefReadIdsKey = 'notif_read_ids';
  static const _prefDeletedIdsKey = 'notif_deleted_ids';

  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    debugPrint('>>> GET Notificaciones solicitado');
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = (prefs.getStringList(_prefReadIdsKey) ?? []).toSet();
      final deletedIds = (prefs.getStringList(_prefDeletedIdsKey) ?? []).toSet();

      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();

      if (token == null || userId == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final List<AppNotification> loaded = [];

      // Ejecución en paralelo con Future.wait y timeout de 7 segundos (no bloqueante)
      await Future.wait([
        // 1. SOLICITUDES DE PROYECTO (Aceptación o rechazo)
        () async {
          try {
            final res = await http.get(
              Uri.parse('$_baseUrl/api/solicitudes-proyecto/mis-solicitudes'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 7));

            if (res.statusCode == 200) {
              final list = jsonDecode(res.body) as List;
              for (final item in list) {
                final id = 'solicitud_${item['id'] ?? item['idSolicitud']}';
                if (deletedIds.contains(id)) continue;

                final estado = (item['estado'] ?? 'pendiente').toString().toLowerCase();
                final proyectoNombre = item['proyectoNombre'] ?? 'Proyecto Ambiental';
                final respuesta = item['respuesta']?.toString();

                String title;
                String message;
                if (estado == 'aceptada') {
                  title = '¡Solicitud aceptada!';
                  message = respuesta != null && respuesta.isNotEmpty
                      ? 'Has sido aceptado en "$proyectoNombre": $respuesta'
                      : 'Tu solicitud para unirte a "$proyectoNombre" fue aceptada.';
                } else if (estado == 'rechazada') {
                  title = 'Solicitud rechazada';
                  message = respuesta != null && respuesta.isNotEmpty
                      ? 'Tu solicitud a "$proyectoNombre" no fue aprobada: $respuesta'
                      : 'Tu solicitud para participar en "$proyectoNombre" fue rechazada.';
                } else {
                  title = 'Solicitud enviada';
                  message = 'Tu postulación a "$proyectoNombre" está en revisión por el coordinador.';
                }

                final dateStr = item['fechaRespuesta'] ?? item['fechaSolicitud'];
                final dt = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

                loaded.add(AppNotification(
                  id: id,
                  type: NotificationType.solicitudProyecto,
                  title: title,
                  message: message,
                  dateTime: dt,
                  isRead: readIds.contains(id),
                  projectId: item['proyectoId'] is num ? (item['proyectoId'] as num).toInt() : null,
                  projectNombre: proyectoNombre,
                  extraStatus: estado,
                  respuestaAdmin: respuesta,
                ));
              }
            } else {
              // Fallback local para solicitudes guardadas
              final localList = await NotificationService.getSolicitudesDeUsuario(userId);
              for (final item in localList) {
                final id = 'local_solicitud_${item['proyectoId']}_${item['fechaEnvio']}';
                if (deletedIds.contains(id)) continue;

                final estado = (item['estado'] ?? 'pendiente').toString().toLowerCase();
                final proyectoNombre = item['proyectoNombre'] ?? 'Proyecto';
                loaded.add(AppNotification(
                  id: id,
                  type: NotificationType.solicitudProyecto,
                  title: estado == 'aceptada' ? '¡Solicitud aceptada!' : estado == 'rechazada' ? 'Solicitud rechazada' : 'Solicitud enviada',
                  message: item['mensaje'] ?? 'Postulación al proyecto $proyectoNombre',
                  dateTime: item['fechaEnvio'] != null ? DateTime.tryParse(item['fechaEnvio']) ?? DateTime.now() : DateTime.now(),
                  isRead: readIds.contains(id),
                  projectId: item['proyectoId'] is num ? (item['proyectoId'] as num).toInt() : null,
                  projectNombre: proyectoNombre,
                  extraStatus: estado,
                  respuestaAdmin: item['respuesta'],
                ));
              }
            }
          } catch (_) {}
        }(),

        // 2. ASIGNACIÓN DE ACTIVIDADES DENTRO DE UN PROYECTO
        () async {
          try {
            final resAct = await http.get(
              Uri.parse('$_baseUrl/api/cronograma-actividades'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 7));

            if (resAct.statusCode == 200) {
              final actBody = jsonDecode(resAct.body);
              final List actList = actBody is List ? actBody : (actBody['content'] ?? []);
              for (final a in actList) {
                final aId = 'actividad_${a['id']}';
                if (deletedIds.contains(aId)) continue;

                final actNombre = a['nombre'] ?? a['titulo'] ?? 'Actividad programada';
                final proyNom = a['proyectoNombre'] ?? a['proyecto']?['nombre'] ?? 'Proyecto';
                final pId = a['proyectoId'] ?? a['proyecto']?['id'];

                final dateStr = a['fechaInicio'] ?? a['fechaCreacion'];
                final dt = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

                loaded.add(AppNotification(
                  id: aId,
                  type: NotificationType.asignacionActividad,
                  title: 'Nueva actividad asignada',
                  message: 'Se programó la actividad "$actNombre" en el proyecto "$proyNom".',
                  dateTime: dt,
                  isRead: readIds.contains(aId),
                  projectId: pId is num ? pId.toInt() : null,
                  projectNombre: proyNom,
                ));
              }
            }
          } catch (_) {}
        }(),

        // 3. REGISTRO DE UN NUEVO REPORTE AMBIENTAL
        () async {
          try {
            final resRep = await http.get(
              Uri.parse('$_baseUrl/api/reportes?size=10'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 7));

            if (resRep.statusCode == 200) {
              final repBody = jsonDecode(resRep.body);
              final List repList = repBody is List ? repBody : (repBody['content'] ?? []);
              for (final r in repList) {
                final rId = 'reporte_${r['id']}';
                if (deletedIds.contains(rId)) continue;

                final titulo = r['titulo'] ?? 'Registro ambiental';
                final sector = r['sector'] ?? 'Páramo del Duende';
                final dateStr = r['fechaReporte'] ?? r['fechaCreacion'];
                final dt = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

                loaded.add(AppNotification(
                  id: rId,
                  type: NotificationType.nuevoReporte,
                  title: 'Nuevo reporte ambiental',
                  message: 'Observación registrada: "$titulo" en sector $sector.',
                  dateTime: dt,
                  isRead: readIds.contains(rId),
                  reportId: r['id'] is num ? (r['id'] as num).toInt() : null,
                  reportTitulo: titulo,
                ));
              }
            }
          } catch (_) {}
        }(),
      ]);

      // Ordenar por fecha más reciente
      loaded.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      _notifications = loaded;
    } catch (e) {
      debugPrint('Error al cargar notificaciones: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final readIds = (prefs.getStringList(_prefReadIdsKey) ?? []).toSet();
      readIds.add(id);
      await prefs.setStringList(_prefReadIdsKey, readIds.toList());
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final allIds = _notifications.map((n) => n.id).toList();
    await prefs.setStringList(_prefReadIdsKey, allIds);
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final deletedIds = (prefs.getStringList(_prefDeletedIdsKey) ?? []).toSet();
    deletedIds.add(id);
    await prefs.setStringList(_prefDeletedIdsKey, deletedIds.toList());
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final deletedIds = (prefs.getStringList(_prefDeletedIdsKey) ?? []).toSet();
    for (final n in _notifications) {
      deletedIds.add(n.id);
    }
    _notifications.clear();
    notifyListeners();
    await prefs.setStringList(_prefDeletedIdsKey, deletedIds.toList());
  }

  void addNotification(AppNotification notification) {
    // Solo permitir los 3 tipos autorizados
    if (notification.type == NotificationType.solicitudProyecto ||
        notification.type == NotificationType.asignacionActividad ||
        notification.type == NotificationType.nuevoReporte) {
      _notifications.insert(0, notification);
      notifyListeners();
    }
  }
}
