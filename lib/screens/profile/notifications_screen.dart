import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'notification_service.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _baseUrl = '${ApiConfig.baseUrl}';

  List<Map<String, dynamic>> _solicitudes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/solicitudes-proyecto/mis-solicitudes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('>>> Status mis-solicitudes: ${response.statusCode}');
      debugPrint('>>> Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as List;
        // Convertir a formato de notificación
        final solicitudes = body
            .map(
              (s) => {
                'proyectoId': s['proyectoId'],
                'proyectoNombre': s['proyectoNombre'],
                'mensaje': s['mensaje'],
                'estado': s['estado'],
                'respuesta': s['respuesta'],
                'fechaEnvio': s['fechaSolicitud'],
              },
            )
            .toList();

        // Ordenar: pendientes primero
        solicitudes.sort((a, b) {
          if (a['estado'] == 'pendiente' && b['estado'] != 'pendiente')
            return -1;
          if (a['estado'] != 'pendiente' && b['estado'] == 'pendiente')
            return 1;
          return (b['fechaEnvio'] ?? '').compareTo(a['fechaEnvio'] ?? '');
        });

        setState(() {
          _solicitudes = solicitudes;
          _isLoading = false;
        });
      } else {
        // Fallback: usar datos locales si el endpoint no existe aún
        await _loadFromLocal();
      }
    } catch (e) {
      await _loadFromLocal();
    }
  }

  // Fallback con datos locales mientras el backend implementa el endpoint
  Future<void> _loadFromLocal() async {
    try {
      final token = await AuthService.getToken();
      final id = await AuthService.getUserId();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/proyecto-miembros/usuario/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> misProyectos;
        if (body is List) {
          misProyectos = body;
        } else if (body is Map && body.containsKey('content')) {
          misProyectos = body['content'] as List;
        } else {
          misProyectos = [];
        }
        await NotificationService.updateEstados(misProyectos, id!);
      }
    } catch (_) {}

    final id = await AuthService.getUserId();
    final solicitudes = await NotificationService.getSolicitudesDeUsuario(id!);
    solicitudes.sort((a, b) {
      if (a['estado'] == 'pendiente' && b['estado'] != 'pendiente') return -1;
      if (a['estado'] != 'pendiente' && b['estado'] == 'pendiente') return 1;
      return (b['fechaEnvio'] ?? '').compareTo(a['fechaEnvio'] ?? '');
    });

    if (mounted) {
      setState(() {
        _solicitudes = solicitudes;
        _isLoading = false;
      });
    }
  }

  /*Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();
      final id = await AuthService.getUserId();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/proyectos/usuario/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> misProyectos;
        if (body is List) {
          misProyectos = body;
        } else if (body is Map && body.containsKey('content')) {
          misProyectos = body['content'] as List;
        } else {
          misProyectos = [];
        }
        await NotificationService.updateEstados(misProyectos, id!);
      }
    } catch (_) {}

    final id = await AuthService.getUserId();
    // Solo cargar solicitudes del usuario actual
    final solicitudes = await NotificationService.getSolicitudesDeUsuario(id!);

    solicitudes.sort((a, b) {
      if (a['estado'] == 'pendiente' && b['estado'] != 'pendiente') return -1;
      if (a['estado'] != 'pendiente' && b['estado'] == 'pendiente') return 1;
      return (b['fechaEnvio'] ?? '').compareTo(a['fechaEnvio'] ?? '');
    });

    if (mounted) {
      setState(() {
        _solicitudes = solicitudes;
        _isLoading = false;
      });
    }
  }*/

  Color _statusColor(String estado) {
    switch (estado) {
      case 'aceptada':
        return Colors.green.shade600;
      case 'rechazada':
        return Colors.red.shade600;
      default:
        return Colors.orange.shade600;
    }
  }

  IconData _statusIcon(String estado) {
    switch (estado) {
      case 'aceptada':
        return Icons.check_circle_rounded;
      case 'rechazada':
        return Icons.cancel_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }

  String _statusLabel(String estado) {
    switch (estado) {
      case 'aceptada':
        return 'Aceptada';
      case 'rechazada':
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  }

  String _timeAgo(String? fechaStr) {
    if (fechaStr == null) return '';
    try {
      final fecha = DateTime.parse(fechaStr);
      final diff = DateTime.now().difference(fecha);
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
      return 'Hace ${diff.inDays} días';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notificaciones',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _solicitudes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tienes notificaciones',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                itemCount: _solicitudes.length,
                itemBuilder: (_, i) {
                  final s = _solicitudes[i];
                  final estado = s['estado'] ?? 'pendiente';
                  final color = _statusColor(estado);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ícono estado
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _statusIcon(estado),
                              color: color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título según estado
                                Text(
                                  estado == 'pendiente'
                                      ? 'Solicitud enviada'
                                      : estado == 'aceptada'
                                      ? '¡Solicitud aceptada!'
                                      : 'Solicitud rechazada',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Nombre del proyecto
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Proyecto: '),
                                      TextSpan(
                                        text: s['proyectoNombre'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Mensaje enviado
                                Text(
                                  s['mensaje'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                // Respuesta del admin si hay
                                if (s['respuesta'] != null &&
                                    s['respuesta'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.admin_panel_settings,
                                          size: 13,
                                          color: color,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            s['respuesta'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: color,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 6),
                                // Fecha
                                Text(
                                  _timeAgo(s['fechaEnvio']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Badge estado
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: color.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _statusLabel(estado),
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
