import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationService {
  static final _storage = const FlutterSecureStorage();
  static const _key = 'solicitudes_enviadas';

  // ── Guardar solicitud enviada ──────────────────────────
  static Future<void> saveSolicitud({
    required int usuarioId,
    required int proyectoId,
    required String proyectoNombre,
    required String mensaje,
  }) async {
    final lista = await getSolicitudes();
    lista.removeWhere(
      (s) => s['proyectoId'] == proyectoId && s['usuarioId'] == usuarioId,
    );
    lista.add({
      'usuarioId': usuarioId,
      'proyectoId': proyectoId,
      'proyectoNombre': proyectoNombre,
      'mensaje': mensaje,
      'estado': 'pendiente',
      'respuesta': null,
      'fechaEnvio': DateTime.now().toIso8601String(),
    });
    await _storage.write(key: _key, value: jsonEncode(lista));
  }

  // ── Actualizar estado según proyectos del usuario ──────
  static Future<void> updateEstados(
    List<dynamic> misProyectos,
    int usuarioId,
  ) async {
    final lista = await getSolicitudes();
    final idsAceptados = misProyectos.map((p) => p['id'] as int).toSet();

    for (final s in lista) {
      if (s['usuarioId'] != usuarioId) continue; // solo del usuario actual
      if (idsAceptados.contains(s['proyectoId'])) {
        s['estado'] = 'aceptada';
        s['mensaje'] = 'Tu solicitud fue aceptada.';
        s['respuesta'] ??= 'Bienvenido al proyecto';
      }
    }
    await _storage.write(key: _key, value: jsonEncode(lista));
  }

  static Future<List<Map<String, dynamic>>> getSolicitudes() async {
    try {
      final data = await _storage.read(key: _key);
      if (data == null) return [];
      final lista = jsonDecode(data) as List;
      return lista.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Obtener todas las solicitudes ──────────────────────
  static Future<List<Map<String, dynamic>>> getSolicitudesDeUsuario(
    int usuarioId,
  ) async {
    final todas = await getSolicitudes();
    return todas.where((s) => s['usuarioId'] == usuarioId).toList();
  }

  // ── Limpiar solicitudes ────────────────────────────────
  static Future<void> clear() async => await _storage.delete(key: _key);
}
