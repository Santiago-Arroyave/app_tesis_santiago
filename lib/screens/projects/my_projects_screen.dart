import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/profile/notification_service.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/projects/project_detail_screen.dart';
import 'package:goblink_park/screens/projects/project_image_helper.dart';

class MyProjectsScreen extends StatefulWidget {
  const MyProjectsScreen({super.key});

  @override
  State<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends State<MyProjectsScreen> {
  List<dynamic> _myProjects = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  String? _errorMessage;

  int _totalActividades = 0;
  int _totalObservaciones = 0;
  int _actividadesCompletadas = 0;
  int _observacionesAportadas = 0;
  int _horasCampo = 0;

  @override
  void initState() {
    super.initState();
    _loadMyProjectsData();
  }

  Future<void> _loadMyProjectsData() async {
    debugPrint('>>> GET Mis Proyectos solicitado');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();
      final userData = await AuthService.getUserData();
      final userEmail = userData?['correo'] ?? userData?['email'];

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Inicia sesión para ver tus proyectos.';
        });
        return;
      }

      List<dynamic> matchedProjects = [];
      Set<int> idsProyectos = {};
      Set<int> idsMiembros = {};

      // 1. Cargar proyectos del usuario directamente desde el endpoint dedicado /api/proyectos/mis-proyectos
      bool loadedDirect = false;
      try {
        final misProyRes = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/proyectos/mis-proyectos'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 50));

        if (misProyRes.statusCode == 200) {
          final body = jsonDecode(misProyRes.body);
          if (body is List) {
            matchedProjects = body;
            loadedDirect = true;
          } else if (body is Map && body.containsKey('content')) {
            matchedProjects = (body['content'] as List?) ?? [];
            loadedDirect = true;
          }
        }
      } catch (_) {}

      // Fallback si mis-proyectos no respondió: consultar membresías y cruzar proyectos
      if (!loadedDirect) {
        try {
          final membRes = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/proyecto-miembros/usuario/$userId'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 50));

          List<dynamic> miembros = [];
          if (membRes.statusCode == 200) {
            final membBody = jsonDecode(membRes.body);
            if (membBody is List) {
              miembros = membBody;
            } else if (membBody is Map && membBody.containsKey('content')) {
              miembros = membBody['content'] as List;
            }
          }

          final miembrosActivos = miembros.where((m) => m['estado'] == true).toList();
          idsProyectos = miembrosActivos
              .map((m) => (m['proyectoId'] as num?)?.toInt() ?? 0)
              .where((id) => id > 0)
              .toSet();
          idsMiembros = miembrosActivos
              .map((m) => (m['id'] as num?)?.toInt() ?? 0)
              .where((id) => id > 0)
              .toSet();

          if (idsProyectos.isNotEmpty) {
            final projRes = await http.get(
              Uri.parse('${ApiConfig.baseUrl}/api/proyectos/todos'),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 50));

            if (projRes.statusCode == 200) {
              final projBody = jsonDecode(projRes.body);
              List<dynamic> all = [];
              if (projBody is List) {
                all = projBody;
              } else if (projBody is Map && projBody.containsKey('content')) {
                all = projBody['content'] as List;
              }
              matchedProjects = all.where((p) => idsProyectos.contains(p['id'])).toList();
            }
          }
        } catch (_) {}
      } else {
        idsProyectos = matchedProjects
            .map((p) => (p['id'] as num?)?.toInt() ?? 0)
            .where((id) => id > 0)
            .toSet();
      }

      // 2. Cargar solicitudes pendientes de NotificationService
      final solicitudes = await NotificationService.getSolicitudesDeUsuario(userId);
      await NotificationService.updateEstados(matchedProjects, userId);
      final pendientes = solicitudes.where((s) => s['estado'] == 'pendiente').toList();

      await ProjectImageHelper.enrichProjectsWithReportImages(
        matchedProjects,
        token: token,
      );

      if (!mounted) return;

      // Renderizar inmediatamente los proyectos cargados para no bloquear al usuario
      setState(() {
        _myProjects = matchedProjects;
        _pendingRequests = pendientes;
        _isLoading = false;
        _errorMessage = null;
      });

      // 3. Métricas reales calculadas de forma desacoplada y resiliente
      int totalActividades = 0;
      int totalObservaciones = 0;
      int actividadesCompletadas = 0;
      int observacionesAportadas = 0;
      int horasCampo = 0;

      // 3.1. Observaciones aportadas por el usuario (total de reportes creados)
      try {
        final statsRes = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/usuarios/$userId/estadisticas'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 50));

        if (statsRes.statusCode == 200) {
          final stats = jsonDecode(statsRes.body);
          if (stats is Map) {
            observacionesAportadas = (stats['totalReportes'] as num?)?.toInt() ?? 0;
          }
        }
      } catch (_) {}

      // Si las estadísticas no trajeron reportes o falló la petición, consultar los reportes reales
      List<dynamic> misReportes = [];
      final Map<int, dynamic> allReportesById = {};
      try {
        final repRes = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/reportes'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 50));

        if (repRes.statusCode == 200) {
          final repBody = jsonDecode(repRes.body);
          final List repList = repBody is List ? repBody : (repBody['content'] ?? []);
          for (final r in repList) {
            if (r is Map) {
              final rId = (r['id'] as num?)?.toInt();
              if (rId != null && rId > 0) {
                allReportesById[rId] = r;
              }
            }
          }
          misReportes = repList.where((r) {
            final uId = r['usuarioId'] ?? r['usuario']?['id'];
            if (uId != null && uId.toString() == userId.toString()) return true;
            final uMail = r['usuarioCorreo'] ?? r['usuario']?['correo'];
            if (userEmail != null &&
                uMail != null &&
                uMail.toString().toLowerCase() == userEmail.toString().toLowerCase()) {
              return true;
            }
            return false;
          }).toList();

          if (observacionesAportadas == 0 && misReportes.isNotEmpty) {
            observacionesAportadas = misReportes.length;
          }
        }
      } catch (_) {}

      // 3.2. Observaciones vinculadas a proyectos (y enriquecimiento de portada del reporte asociado)
      if (idsProyectos.isNotEmpty) {
        final misReporteIds = misReportes
            .map((r) => (r['id'] as num?)?.toInt() ?? 0)
            .where((id) => id > 0)
            .toSet();

        for (final pId in idsProyectos) {
          try {
            final vinculadosRes = await http.get(
              Uri.parse('${ApiConfig.baseUrl}/api/proyecto-reportes/proyecto/$pId'),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 50));

            if (vinculadosRes.statusCode == 200) {
              final vincBody = jsonDecode(vinculadosRes.body);
              final List vincList = vincBody is List ? vincBody : (vincBody['content'] ?? []);
              final List<dynamic> projectReportes = [];
              for (final vr in vincList) {
                final repId = (vr['reporteId'] as num?)?.toInt() ?? 0;
                if (misReporteIds.contains(repId)) {
                  totalObservaciones++;
                }
                if (allReportesById.containsKey(repId)) {
                  projectReportes.add(allReportesById[repId]);
                } else {
                  projectReportes.add(vr);
                }
              }
              if (projectReportes.isNotEmpty) {
                for (final proj in _myProjects) {
                  if (proj is Map && (proj['id'] as num?)?.toInt() == pId) {
                    proj['reportes'] = projectReportes;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      // 3.3. Actividades asignadas y completadas (solo si el usuario tiene proyectos activos)
      if (idsProyectos.isNotEmpty) {
        try {
          final actRes = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/cronograma-actividades'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 50));

          if (actRes.statusCode == 200) {
            final actBody = jsonDecode(actRes.body);
            final List actList = actBody is List ? actBody : (actBody['content'] ?? []);

            final asignadasUsuario = actList.where((a) {
              final projId = (a['proyectoId'] ?? a['proyecto']?['id'] as num?)?.toInt();
              if (projId != null && !idsProyectos.contains(projId)) return false;

              final respId = (a['usuarioResponsableId'] ?? a['usuarioId'] as num?)?.toInt();
              final miembroId = (a['proyectoMiembroId'] as num?)?.toInt();

              final isUserResp = respId != null && respId == userId;
              final isUserMember = miembroId != null && idsMiembros.isNotEmpty && idsMiembros.contains(miembroId);

              return isUserResp || isUserMember;
            }).toList();

            totalActividades = asignadasUsuario.length;
            actividadesCompletadas = asignadasUsuario.where((a) {
              final est = (a['estado'] ?? '').toString().toLowerCase();
              return est == 'completada' || est == 'finalizada';
            }).length;

            num sumHoras = 0;
            for (final a in asignadasUsuario) {
              final est = (a['estado'] ?? '').toString().toLowerCase();
              if (est == 'completada' || est == 'finalizada') {
                final h = a['horas'] ?? a['horasDedicadas'] ?? a['duracionHoras'] ?? a['horasEstimadas'];
                if (h is num) sumHoras += h;
              }
            }
            horasCampo = sumHoras.toInt();
          }
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _totalActividades = totalActividades;
        _totalObservaciones = totalObservaciones;
        _actividadesCompletadas = actividadesCompletadas;
        _observacionesAportadas = observacionesAportadas;
        _horasCampo = horasCampo;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_myProjects.isEmpty) {
          _errorMessage = 'Error de conexión: $e';
        }
      });
    }
  }

  void _showCancelRequestModal(Map<String, dynamic> req) {
    final proyectoId = req['proyectoId'] as int? ?? 0;
    final proyectoNombre = req['proyectoNombre']?.toString() ?? 'Proyecto';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3B1C1C) : const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Color(0xFFD32F2F),
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '¿Cancelar solicitud?',
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Si cancelas la solicitud al proyecto "$proyectoNombre", no podrás participar en sus actividades hasta postularte nuevamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF222E27) : const Color(0xFFF3F4F6),
                        side: BorderSide(
                          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Mantener',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF374151),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final userId = await AuthService.getUserId();
                        if (userId != null) {
                          await NotificationService.cancelSolicitud(
                            usuarioId: userId,
                            proyectoId: proyectoId,
                          );
                        }
                        setState(() {
                          _pendingRequests.removeWhere(
                            (s) => s['proyectoId'] == proyectoId,
                          );
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Solicitud cancelada con éxito.'),
                              backgroundColor: Color(0xFF1E5E3A),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancelar solicitud',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  double _getProjectProgress(dynamic p) {
    if (p['porcentajeAvance'] != null) {
      final v = double.tryParse(p['porcentajeAvance'].toString());
      if (v != null) return (v / 100.0).clamp(0.0, 1.0);
    }
    final estado = (p['estadoProyectoNombre'] ?? p['estado'] ?? '')
        .toString()
        .toLowerCase();
    if (estado.contains('finaliz') || estado.contains('completa')) return 1.0;
    if (estado.contains('ejecuci')) return 0.65;
    return 0.35;
  }

  String _getImageUrl(dynamic p) {
    return ProjectImageHelper.resolveImageUrl(p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Logo verde.png',
              width: 26,
              height: 26,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.park,
                color: Color(0xFF1E5E3A),
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Goblin Park',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMyProjectsData,
          color: const Color(0xFF1E5E3A),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1E5E3A),
                    strokeWidth: 2.5,
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: _loadMyProjectsData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E5E3A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título de la vista
                          Text(
                            'Mis proyectos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Proyectos en los que participas activamente',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Panel Superior de 3 Indicadores
                          _buildIndicatorPanel(),
                          const SizedBox(height: 16),

                          // Tarjeta "Mi participación"
                          _buildParticipationCard(),
                          const SizedBox(height: 20),

                          // Sección "Proyectos activos"
                          _buildActiveProjectsSection(),
                          const SizedBox(height: 22),

                          // Sección "Mis solicitudes pendientes"
                          _buildPendingRequestsSection(),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  // Panel superior de 3 tarjetas compactas
  Widget _buildIndicatorPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _buildMetricCard(
          icon: Icons.eco_rounded,
          iconColor: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
          bgColor: isDark ? const Color(0xFF1B2620) : const Color(0xFFE8F5E9),
          title: 'Proyectos',
          subtitle: 'activos',
          value: '${_myProjects.length}',
        ),
        const SizedBox(width: 10),
        _buildMetricCard(
          icon: Icons.assignment_outlined,
          iconColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1565C0),
          bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE3F2FD),
          title: 'Actividades',
          subtitle: 'asignadas',
          value: '$_totalActividades',
        ),
        const SizedBox(width: 10),
        _buildMetricCard(
          icon: Icons.analytics_outlined,
          iconColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF7B1FA2),
          bgColor: isDark ? const Color(0xFF2E1065) : const Color(0xFFF3E5F5),
          title: 'Observaciones',
          subtitle: 'vinculadas',
          value: '$_totalObservaciones',
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$title\n$subtitle',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta destacada "Mi participación"
  Widget _buildParticipationCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.military_tech_outlined,
                color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Mi participación en campo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildParticipationStat(
                value: '$_actividadesCompletadas',
                label: 'Actividades\ncompletadas',
                color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
              ),
              Container(width: 1, height: 36, color: dividerColor),
              _buildParticipationStat(
                value: '$_observacionesAportadas',
                label: 'Observaciones\naportadas',
                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1565C0),
              ),
              Container(width: 1, height: 36, color: dividerColor),
              _buildParticipationStat(
                value: '$_horasCampo h',
                label: 'Horas de\ncampo',
                color: const Color(0xFFD97706),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipationStat({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  // Lista de proyectos activos
  Widget _buildActiveProjectsSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Proyectos activos',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B2620) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_myProjects.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_myProjects.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 42,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                Text(
                  'Aún no perteneces a ningún proyecto',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Explora iniciativas de conservación y solicita unirte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
        else
          ..._myProjects.map((p) => _buildActiveProjectCard(p)),
      ],
    );
  }

  Widget _buildActiveProjectCard(dynamic project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final id = project['id'] is int
        ? project['id'] as int
        : int.tryParse(project['id']?.toString() ?? '0') ?? 0;
    final nombre = project['nombre']?.toString() ?? 'Proyecto activo';
    final categoria = project['categoriaNombre']?.toString() ??
        project['categoria']?.toString() ??
        'Conservación';
    final entidad = project['entidadResponsableNombre'] ??
        project['creadoPorNombre'] ??
        'Parques Nacionales';
    final progress = _getProjectProgress(project);
    final progressPercent = (progress * 100).toInt();
    final imageUrl = _getImageUrl(project);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(
                  projectId: id,
                  initialProject:
                      project is Map<String, dynamic> ? project : null,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 75,
                    height: 75,
                    child: (imageUrl.isNotEmpty &&
                            (imageUrl.startsWith('http://') ||
                                imageUrl.startsWith('https://')))
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B2620) : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Miembro activo',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$progressPercent%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$categoria • $entidad',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? const Color(0xFF2D3748)
                              : const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Sección "Mis solicitudes pendientes"
  Widget _buildPendingRequestsSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Mis solicitudes pendientes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF332A15) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_pendingRequests.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pendingRequests.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Center(
              child: Text(
                'No tienes solicitudes pendientes de aprobación.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
          )
        else
          ..._pendingRequests.map((req) => _buildPendingRequestCard(req)),
      ],
    );
  }

  Widget _buildPendingRequestCard(Map<String, dynamic> req) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final projectName = req['proyectoNombre']?.toString() ?? 'Proyecto ambiental';
    final fecha = req['fechaEnvio']?.toString() ?? '';
    String fechaStr = 'Reciente';
    if (fecha.isNotEmpty) {
      final dt = DateTime.tryParse(fecha);
      if (dt != null) {
        fechaStr = '${dt.day}/${dt.month}/${dt.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF332A15) : const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Color(0xFFF59E0B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF332A15) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Pendiente',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      fechaStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Esperando revisión del coordinador',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFF6B7280),
              size: 20,
            ),
            tooltip: 'Opciones',
            onPressed: () => _showCancelRequestModal(req),
          ),
        ],
      ),
    );
  }
}
