import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/models/app_notification.dart';
import 'package:goblink_park/providers/notification_provider.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/projects/project_detail_screen.dart';
import 'package:goblink_park/screens/reports/report_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _getTypeColor(AppNotification n) {
    switch (n.type) {
      case NotificationType.solicitudProyecto:
        if (n.extraStatus == 'aceptada') return const Color(0xFF16A34A);
        if (n.extraStatus == 'rechazada') return const Color(0xFFDC2626);
        return const Color(0xFFD97706);
      case NotificationType.asignacionActividad:
        return const Color(0xFF2563EB);
      case NotificationType.nuevoReporte:
        return const Color(0xFF059669);
    }
  }

  IconData _getTypeIcon(AppNotification n) {
    switch (n.type) {
      case NotificationType.solicitudProyecto:
        if (n.extraStatus == 'aceptada') return Icons.check_circle_rounded;
        if (n.extraStatus == 'rechazada') return Icons.cancel_rounded;
        return Icons.pending_actions_rounded;
      case NotificationType.asignacionActividad:
        return Icons.assignment_turned_in_rounded;
      case NotificationType.nuevoReporte:
        return Icons.eco_rounded;
    }
  }

  String _getTypeBadge(AppNotification n) {
    switch (n.type) {
      case NotificationType.solicitudProyecto:
        return 'Proyecto';
      case NotificationType.asignacionActividad:
        return 'Actividad';
      case NotificationType.nuevoReporte:
        return 'Reporte';
    }
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    AppNotification n,
    NotificationProvider provider,
  ) async {
    // 1. Marcar como leída
    await provider.markAsRead(n.id);

    if (!context.mounted) return;

    // 2. Navegación directa (Deep Linking)
    if (n.type == NotificationType.solicitudProyecto ||
        n.type == NotificationType.asignacionActividad) {
      if (n.projectId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(
              projectId: n.projectId!,
              initialProject: n.projectNombre != null
                  ? {'id': n.projectId, 'nombre': n.projectNombre}
                  : null,
            ),
          ),
        );
      }
    } else if (n.type == NotificationType.nuevoReporte) {
      if (n.reportId != null) {
        // Consultar el reporte completo o abrir con datos disponibles
        _openReportDetail(context, n.reportId!, n.reportTitulo);
      }
    }
  }

  Future<void> _openReportDetail(
    BuildContext context,
    int reportId,
    String? titulo,
  ) async {
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/reportes/$reportId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!context.mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailScreen(reporte: data),
          ),
        );
        return;
      }
    } catch (_) {}

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportDetailScreen(
            reporte: {
              'id': reportId,
              'titulo': titulo ?? 'Reporte ambiental',
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F3A22)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notificaciones",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F3A22),
          ),
        ),
        centerTitle: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) {
              return Row(
                children: [
                  if (notifProvider.unreadCount > 0)
                    IconButton(
                      icon: const Icon(Icons.done_all_rounded, color: Color(0xFF1E5E3A), size: 22),
                      tooltip: 'Marcar todas como leídas',
                      onPressed: () => notifProvider.markAllAsRead(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF0F3A22), size: 22),
                    tooltip: 'Actualizar',
                    onPressed: () => notifProvider.loadNotifications(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notifProvider, child) {
          if (notifProvider.isLoading && notifProvider.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E5E3A)),
            );
          }

          if (notifProvider.notifications.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          final notifications = notifProvider.notifications;

          return RefreshIndicator(
            color: const Color(0xFF1E5E3A),
            onRefresh: () => notifProvider.loadNotifications(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final color = _getTypeColor(notif);
                final icon = _getTypeIcon(notif);
                final badge = _getTypeBadge(notif);

                return Dismissible(
                  key: Key(notif.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 6),
                        Text(
                          "Eliminar",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) {
                    notifProvider.deleteNotification(notif.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Notificación "${notif.title}" eliminada'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: notif.isRead
                          ? cardBg
                          : (isDark ? const Color(0xFF262626) : const Color(0xFFF0FDF4)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: notif.isRead
                            ? (isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB))
                            : const Color(0xFF86EFAC),
                        width: notif.isRead ? 1.0 : 1.3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _handleNotificationTap(context, notif, notifProvider),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icono temático con círculo decorativo
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withAlpha(25),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: color.withAlpha(80), width: 1.2),
                                ),
                                child: Icon(icon, color: color, size: 22),
                              ),
                              const SizedBox(width: 12),

                              // Contenido
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Badge de Tipo
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: color.withAlpha(20),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            badge,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        // Tiempo
                                        Text(
                                          _formatTimeAgo(notif.dateTime),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (!notif.isRead) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF1E5E3A),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: notif.isRead ? FontWeight.bold : FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif.message,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // ESTADO VACÍO (EMPTY STATE) SEGÚN DISEÑO
  // ===========================================================================
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Stack(
      children: [
        // 1. Imagen de fondo del páramo
        Positioned.fill(
          child: Image.asset(
            'assets/images/Fondo.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFF9FAFB)),
          ),
        ),

        // 2. Capa traslúcida para legibilidad y contraste
        Positioned.fill(
          child: Container(
            color: isDark
                ? Colors.black.withAlpha(225)
                : Colors.white.withAlpha(225),
          ),
        ),

        // 3. Contenido centrado: campana con hojas verdes, textos y botón volver
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono central de campana con hojas verdes alrededor
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE8F5E9),
                    border: Border.all(
                      color: const Color(0xFF1E5E3A).withAlpha(80),
                      width: 2.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1E1E5E3A),
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 14,
                          right: 18,
                          child: Icon(
                            Icons.eco,
                            size: 20,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 18,
                          child: Icon(
                            Icons.eco,
                            size: 18,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 50,
                          color: Color(0xFF1E5E3A),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Título: «No tienes notificaciones»
                const Text(
                  "No tienes notificaciones",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F3A22),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtítulo
                const Text(
                  "Cuando haya nuevas alertas, reportes o mensajes, los verás aquí.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 30),

                // Botón verde: «Volver al inicio»
                SizedBox(
                  width: 200,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      "Volver al inicio",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5E3A),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
