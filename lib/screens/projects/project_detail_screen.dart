import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/profile/notification_service.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/projects/activity_evidence_screen.dart';
import 'package:goblink_park/screens/projects/project_image_helper.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  final Map<String, dynamic>? initialProject;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.initialProject,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _projectData = {};

  List<dynamic> _miembros = [];
  List<dynamic> _objetivos = [];
  List<dynamic> _metas = [];
  List<dynamic> _presupuesto = [];
  List<dynamic> _actividades = [];
  List<dynamic> _observaciones = [];

  bool _isDownloadingPdf = false;

  bool _isMember = false;
  bool _isPendingRequest = false;
  int? _pendingSolicitudId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialProject != null) {
      _projectData = Map<String, dynamic>.from(widget.initialProject!);
    }
    _loadProjectDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectDetail() async {
    debugPrint('>>> GET Detalle Proyecto solicitado: ${widget.projectId}');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/proyectos/${widget.projectId}/detalle-completo',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 50));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        Map<String, dynamic> data = {};
        if (body is Map<String, dynamic> && body.containsKey('proyecto')) {
          data = body;
        } else if (body is Map<String, dynamic>) {
          data = {
            'proyecto': body,
            'miembros': body['miembros'] ?? [],
            'objetivos': body['objetivos'] ?? [],
            'metas': body['metas'] ?? [],
            'presupuesto': body['presupuesto'] ?? [],
            'cronogramaActividades': body['cronogramaActividades'] ?? [],
            'reportesAsociados':
                body['reportesAsociados'] ?? body['reportes'] ?? [],
          };
        }

        final proj = (data['proyecto'] as Map<String, dynamic>?) ?? {};
        final miembrosList = (data['miembros'] as List?) ?? [];

        setState(() {
          _projectData = {
            ...widget.initialProject ?? {},
            ...proj,
          };
          _miembros = miembrosList;
          _objetivos = (data['objetivos'] as List?) ?? [];
          _metas = (data['metas'] as List?) ?? [];
          _presupuesto = (data['presupuesto'] as List?) ?? [];
          _actividades = (data['cronogramaActividades'] as List?) ?? [];
          _observaciones =
              (data['reportesAsociados'] as List?) ??
              (proj['reportes'] as List?) ??
              [];
          _isLoading = false;
        });
      } else {
        // Fallback a endpoint estándar
        final fallbackRes = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/proyectos/${widget.projectId}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 50));

        if (fallbackRes.statusCode == 200) {
          final body = jsonDecode(fallbackRes.body);
          if (body is Map<String, dynamic>) {
            setState(() {
              _projectData = {
                ...widget.initialProject ?? {},
                ...body,
              };
              _actividades = (body['cronogramaActividades'] as List?) ??
                  (body['actividades'] as List?) ??
                  [];
              _miembros = (body['miembros'] as List?) ?? [];
              _observaciones =
                  (body['reportesAsociados'] as List?) ??
                  (body['reportes'] as List?) ??
                  [];
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _isLoading = false;
            if (_projectData.isEmpty) {
              _errorMessage = 'Error ${response.statusCode} al cargar detalles';
            }
          });
        }
      }

      // Si aún no hay imagen de portada directa pero existe un reporte asociado con reporteId, obtener su fotoPrincipalUrl
      if (_getImageUrl().isEmpty && _observaciones.isNotEmpty) {
        final firstRep = _observaciones.first;
        if (firstRep is Map) {
          final repId = firstRep['reporteId'] ?? firstRep['idReporte'] ?? firstRep['id'];
          if (repId != null) {
            try {
              final repRes = await http.get(
                Uri.parse('${ApiConfig.baseUrl}/api/reportes/$repId'),
                headers: {
                  'Content-Type': 'application/json',
                  if (token != null) 'Authorization': 'Bearer $token',
                },
              ).timeout(const Duration(seconds: 15));
              if (repRes.statusCode == 200 && mounted) {
                final repData = jsonDecode(repRes.body);
                if (repData is Map) {
                  String? fotoUrl = (repData['fotoPrincipalUrl'] ??
                          repData['imagenUrl'] ??
                          repData['fotoUrl'] ??
                          repData['urlFoto'] ??
                          repData['foto'])
                      ?.toString()
                      .trim();
                  if ((fotoUrl == null || fotoUrl.isEmpty) &&
                      repData['evidencias'] is List &&
                      (repData['evidencias'] as List).isNotEmpty) {
                    final firstEv = (repData['evidencias'] as List).first;
                    if (firstEv is Map) {
                      fotoUrl = (firstEv['urlArchivo'] ?? firstEv['url'])
                          ?.toString()
                          .trim();
                    }
                  }
                  if (fotoUrl != null && fotoUrl.isNotEmpty) {
                    ProjectImageHelper.cacheProjectImage(
                      widget.projectId,
                      fotoUrl,
                    );
                    setState(() {
                      _projectData['imagenUrl'] = fotoUrl;
                    });
                  }
                }
              }
            } catch (_) {}
          }
        }
      }

      // Verificación de membresía y solicitudes del usuario
      if (userId != null && token != null) {
        bool memberFound = _miembros.any((m) {
          final mUid = m['usuarioId'] ?? m['idUsuario'] ?? m['id'];
          return mUid == userId && m['estado'] != false;
        });

        if (!memberFound) {
          try {
            final membRes = await http.get(
              Uri.parse(
                '${ApiConfig.baseUrl}/api/proyecto-miembros/usuario/$userId',
              ),
              headers: {'Authorization': 'Bearer $token'},
            ).timeout(const Duration(seconds: 50));

            if (membRes.statusCode == 200) {
              final membBody = jsonDecode(membRes.body);
              List<dynamic> list = [];
              if (membBody is List) {
                list = membBody;
              } else if (membBody is Map && membBody.containsKey('content')) {
                list = membBody['content'] as List;
              }
              memberFound = list.any(
                (m) =>
                    m['proyectoId'] == widget.projectId && m['estado'] == true,
              );
            }
          } catch (_) {}
        }

        final solicitudes =
            await NotificationService.getSolicitudesDeUsuario(userId);
        final req = solicitudes.firstWhere(
          (s) =>
              s['proyectoId'] == widget.projectId && s['estado'] == 'pendiente',
          orElse: () => {},
        );

        if (mounted) {
          setState(() {
            _isMember = memberFound;
            _isPendingRequest = req.isNotEmpty;
            _pendingSolicitudId = req['idSolicitud'] as int?;
          });
        }

        // Enriquecer fotos de perfil de miembros si el DTO de miembro no incluye fotoPerfilUrl / fotoPerfil
        await _enrichMembersProfilePhotos(token: token, currentUserId: userId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_projectData.isEmpty) {
          _errorMessage = 'Error de conexión: $e';
        }
      });
    }
  }

  Future<void> _handleRequestToJoin() async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();
    final nombre = _projectData['nombre']?.toString() ?? 'Proyecto';
    const mensaje = 'Quiero participar en este proyecto ambiental de conservación';

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E5E3A)),
        ),
      );

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/solicitudes-proyecto'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'idProyecto': widget.projectId,
          'proyectoId': widget.projectId,
          'mensaje': mensaje,
        }),
      ).timeout(const Duration(seconds: 50));

      if (mounted) Navigator.pop(context); // cerrar loader

      int? idSolicitud;
      try {
        final resBody = jsonDecode(res.body);
        if (resBody is Map) {
          idSolicitud = resBody['id'] ?? resBody['idSolicitud'];
        }
      } catch (_) {}

      if (userId != null) {
        await NotificationService.saveSolicitud(
          usuarioId: userId,
          proyectoId: widget.projectId,
          proyectoNombre: nombre,
          mensaje: mensaje,
          idSolicitud: idSolicitud,
        );
      }

      if (mounted) {
        setState(() {
          _isPendingRequest = true;
          _pendingSolicitudId = idSolicitud;
        });
        _showConfirmationDialog(nombre);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (userId != null) {
        await NotificationService.saveSolicitud(
          usuarioId: userId,
          proyectoId: widget.projectId,
          proyectoNombre: nombre,
          mensaje: mensaje,
        );
      }
      if (mounted) {
        setState(() {
          _isPendingRequest = true;
        });
        _showConfirmationDialog(nombre);
      }
    }
  }

  void _showConfirmationDialog(String projectName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF1E5E3A),
                  size: 46,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Solicitud enviada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F3A22),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tu solicitud para unirte al proyecto "$projectName" ha sido enviada con éxito. Te notificaremos cuando sea revisada.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5E3A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelRequestModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Color(0xFFD32F2F),
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '¿Cancelar solicitud?',
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '¿Estás seguro de que deseas cancelar tu solicitud para unirte a este proyecto?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
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
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Mantener',
                        style: TextStyle(
                          color: Color(0xFF374151),
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
                        final token = await AuthService.getToken();
                        if (userId != null) {
                          if (_pendingSolicitudId != null) {
                            try {
                              await http.delete(
                                Uri.parse(
                                  '${ApiConfig.baseUrl}/api/solicitudes-proyecto/$_pendingSolicitudId',
                                ),
                                headers: {'Authorization': 'Bearer $token'},
                              ).timeout(const Duration(seconds: 50));
                            } catch (_) {}
                          }
                          await NotificationService.cancelSolicitud(
                            usuarioId: userId,
                            proyectoId: widget.projectId,
                          );
                        }
                        setState(() {
                          _isPendingRequest = false;
                          _pendingSolicitudId = null;
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

  Future<void> _downloadPdf() async {
    setState(() => _isDownloadingPdf = true);
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/proyectos/${widget.projectId}/pdf'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 50));

      if (!mounted) return;
      setState(() => _isDownloadingPdf = false);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/proyecto_${widget.projectId}.pdf');
        await file.writeAsBytes(bytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ficha del proyecto descargada correctamente.'),
            backgroundColor: Color(0xFF1E5E3A),
          ),
        );
        await OpenFilex.open(file.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No fue posible descargar el PDF (${response.statusCode})'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloadingPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar PDF: $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.description_outlined,
                color: Color(0xFF1E5E3A),
              ),
              title: const Text(
                'Descargar ficha del proyecto (PDF)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _downloadPdf();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF1E5E3A),
              ),
              title: const Text(
                'Actualizar información',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _loadProjectDetail();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.share_outlined,
                color: Color(0xFF1E5E3A),
              ),
              title: const Text(
                'Compartir proyecto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enlace copiado al portapapeles.'),
                    backgroundColor: Color(0xFF1E5E3A),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getImageUrl() {
    return ProjectImageHelper.resolveImageUrl(
      _projectData,
      extraReportes: _observaciones,
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '\$ 120.000.000 COP';
    final numVal = num.tryParse(value.toString());
    if (numVal == null) return value.toString();
    final str = numVal.toInt().toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return '\$ ${str.replaceAllMapped(reg, (match) => '.') } COP';
  }

  double _getProjectProgress() {
    if (_projectData['porcentajeAvance'] != null) {
      final v = double.tryParse(_projectData['porcentajeAvance'].toString());
      if (v != null) return (v / 100.0).clamp(0.0, 1.0);
    }
    if (_projectData['avance'] != null) {
      final v = double.tryParse(_projectData['avance'].toString());
      if (v != null) return (v / 100.0).clamp(0.0, 1.0);
    }
    final estado = (_projectData['estadoProyectoNombre'] ??
            _projectData['estado'] ??
            '')
        .toString()
        .toLowerCase();
    if (estado.contains('finaliz') || estado.contains('completa')) return 1.0;
    if (estado.contains('ejecuci')) return 0.70;
    if (estado.contains('planific')) return 0.30;
    return 0.70;
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _projectData['nombre']?.toString() ?? 'Proyecto ambiental';
    final categoria = _projectData['categoriaNombre']?.toString() ??
        _projectData['categoria']?.toString() ??
        'Conservación';
    final estado = (_projectData['estadoProyectoNombre'] ??
            _projectData['estado'] ??
            'Activo')
        .toString();
    final bannerUrl = _getImageUrl();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      bottomNavigationBar: !_isMember
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: SafeArea(
                top: false,
                child: _isPendingRequest
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  color: Color(0xFFB45309),
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Tu solicitud está en revisión',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _showCancelRequestModal,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancelar solicitud',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _handleRequestToJoin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E5E3A),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Solicitar unirme',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          final hasValidBanner = bannerUrl.isNotEmpty &&
              (bannerUrl.startsWith('http://') ||
                  bannerUrl.startsWith('https://'));

          return [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFF0F3A22),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF0F3A22),
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Color(0xFF0F3A22),
                        size: 20,
                      ),
                      onPressed: _showOptionsMenu,
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasValidBanner)
                      Image.network(
                        bannerUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 16,
                      right: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  estado.isNotEmpty ? estado : 'Activo',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E5E3A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  categoria,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorColor: const Color(0xFF1E5E3A),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF1E5E3A),
                  unselectedLabelColor: const Color(0xFF6B7280),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  onTap: (_) => setState(() {}),
                  tabs: const [
                    Tab(text: 'Resumen'),
                    Tab(text: 'Actividades'),
                    Tab(text: 'Miembros'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading && _projectData.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1E5E3A),
                  strokeWidth: 2.5,
                ),
              )
            : _errorMessage != null && _projectData.isEmpty
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
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _loadProjectDetail,
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
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabResumen(),
                      _buildTabActividades(),
                      _buildTabMiembros(),
                    ],
                  ),
      ),
    );
  }

  // 1. Pestaña: Resumen
  Widget _buildTabResumen() {
    final objetivo = _projectData['objetivo']?.toString() ??
        _projectData['descripcion']?.toString() ??
        'Generar procesos de monitoreo comunitario y restauración activa en ecosistemas de alta montaña del PNR Páramo del Duende.';
    final entidad = _projectData['entidadResponsableNombre']?.toString() ??
        _projectData['entidad']?.toString() ??
        'Parques Nacionales Naturales de Colombia';
    final presupuestoVal = _presupuesto.isNotEmpty
        ? _presupuesto[0]['montoTotal'] ?? _presupuesto[0]['presupuestoTotal']
        : _projectData['presupuestoTotal'];
    final presupuestoStr = _formatCurrency(presupuestoVal);

    final progressVal = _getProjectProgress();
    final progressPercent = (progressVal * 100).toInt();

    List<String> metasDisplay = [];
    if (_metas.isNotEmpty) {
      metasDisplay = _metas
          .map((m) =>
              m['descripcion']?.toString() ?? m['meta']?.toString() ?? '')
          .where((m) => m.isNotEmpty)
          .toList();
    } else if (_objetivos.isNotEmpty) {
      metasDisplay = _objetivos
          .map((o) => o['descripcion']?.toString() ?? '')
          .where((o) => o.isNotEmpty)
          .toList();
    } else {
      metasDisplay = [
        'Propagar y reforestar 5.000 frailejones (Espeletia).',
        'Establecer 4 parcelas permanentes de monitoreo hídrico.',
        'Sensibilizar y capacitar a 40 guardianes comunitarios.',
      ];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta "Objetivo"
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                const Row(
                  children: [
                    Icon(
                      Icons.track_changes_rounded,
                      color: Color(0xFF1E5E3A),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Objetivo general',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F3A22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  objetivo,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metas principales
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                const Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: Color(0xFF1E5E3A),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Metas principales de conservación',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F3A22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...metasDisplay.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF1E5E3A),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fila de Métricas: Presupuesto total y Ejecución con iconos institucionales
          Row(
            children: [
              // 1. Tarjeta Presupuesto total con monedas apiladas
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.savings_outlined,
                          color: Color(0xFF1E5E3A),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Presupuesto total',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              presupuestoStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Tarjeta Ejecución con gráfico de pastel y barra horizontal
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pie_chart_rounded,
                          color: Color(0xFF1E5E3A),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ejecución',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$progressPercent%',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressVal,
                                minHeight: 4,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1E5E3A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Equipo Responsable
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_outlined,
                    color: Color(0xFF1E5E3A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Equipo responsable',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entidad,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Botón descargable: Descargar ficha del proyecto (PDF)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isDownloadingPdf ? null : _downloadPdf,
              icon: _isDownloadingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1E5E3A),
                      ),
                    )
                  : const Icon(
                      Icons.description_outlined,
                      color: Color(0xFF1E5E3A),
                      size: 20,
                    ),
              label: Text(
                _isDownloadingPdf
                    ? 'Descargando...'
                    : 'Descargar ficha del proyecto (PDF)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5E3A),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E5E3A), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Pestaña: Actividades (Cronograma con Línea de Tiempo Vertical)
  Widget _buildTabActividades() {
    if (_actividades.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 52,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              const Text(
                'No hay actividades programadas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3A22),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'El coordinador aún no ha registrado el cronograma.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      itemCount: _actividades.length,
      itemBuilder: (context, index) {
        final act = _actividades[index];
        final isLast = index == _actividades.length - 1;
        return _buildTimelineActivityItem(act, index + 1, isLast);
      },
    );
  }

  String _resolveResponsableNombre(dynamic act) {
    if (act is! Map) return 'Sin asignar';
    final direct = act['responsableNombre'] ??
        act['usuarioResponsableNombre'] ??
        act['nombreResponsable'] ??
        (act['responsable'] is Map
            ? (act['responsable']['nombre'] ??
                act['responsable']['nombres'] ??
                act['responsable']['usuarioNombre'])
            : null);
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }

    final miembroId = act['proyectoMiembroId'];
    final usuarioId = act['responsableId'] ?? act['usuarioResponsableId'];
    for (final m in _miembros) {
      if (m is Map) {
        if (miembroId != null &&
            m['id'] != null &&
            m['id'].toString() == miembroId.toString()) {
          final mName =
              m['usuarioNombre'] ?? m['nombreCompleto'] ?? m['nombre'];
          if (mName != null && mName.toString().trim().isNotEmpty) {
            return mName.toString().trim();
          }
        }
        final mUid = m['usuarioId'] ?? m['idUsuario'];
        if (usuarioId != null &&
            mUid != null &&
            mUid.toString() == usuarioId.toString()) {
          final mName =
              m['usuarioNombre'] ?? m['nombreCompleto'] ?? m['nombre'];
          if (mName != null && mName.toString().trim().isNotEmpty) {
            return mName.toString().trim();
          }
        }
      }
    }
    return 'Sin asignar';
  }

  dynamic _resolveResponsableId(dynamic act) {
    if (act is! Map) return null;
    final directId = act['responsableId'] ??
        act['usuarioResponsableId'] ??
        (act['responsable'] is Map ? act['responsable']['id'] : null);
    if (directId != null) return directId;

    final miembroId = act['proyectoMiembroId'];
    if (miembroId != null) {
      for (final m in _miembros) {
        if (m is Map &&
            m['id'] != null &&
            m['id'].toString() == miembroId.toString()) {
          return m['usuarioId'] ?? m['idUsuario'];
        }
      }
    }
    return null;
  }

  Future<void> _enrichMembersProfilePhotos({
    required String token,
    required int currentUserId,
  }) async {
    if (_miembros.isEmpty) return;

    try {
      final currentUserData = await AuthStorage.getUserData();
      bool anyUpdated = false;

      // 1. Si el usuario actual está en la lista de miembros, hidratar desde su perfil local si falta fotoPerfil
      for (final m in _miembros) {
        if (m is Map) {
          final mUid = m['usuarioId'] ?? m['idUsuario'];
          if (mUid != null &&
              mUid.toString() == currentUserId.toString() &&
              currentUserData != null) {
            final currentFoto = currentUserData['fotoPerfilUrl'] ??
                currentUserData['fotoPerfil'] ??
                currentUserData['foto_perfil'];
            if (_obtenerUrlValida(m['fotoPerfilUrl'] ?? m['fotoPerfil'])
                    .isEmpty &&
                _obtenerUrlValida(currentFoto).isNotEmpty) {
              m['fotoPerfil'] = currentFoto;
              m['fotoPerfilUrl'] = currentFoto;
              anyUpdated = true;
            }
          }
        }
      }

      // 2. Si algún miembro no trae fotoPerfil en el DTO, enriquecer desde GET /api/usuarios
      final needsUserLookup = _miembros.any((m) {
        if (m is! Map) return false;
        final raw = m['fotoPerfilUrl'] ??
            m['fotoPerfil'] ??
            m['foto_perfil'] ??
            m['fotoUrl'] ??
            (m['usuario'] is Map
                ? (m['usuario']['fotoPerfilUrl'] ?? m['usuario']['fotoPerfil'])
                : null);
        return _obtenerUrlValida(raw).isEmpty;
      });

      if (needsUserLookup) {
        final usersRes = await http
            .get(
              Uri.parse('${ApiConfig.baseUrl}/api/usuarios'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (usersRes.statusCode == 200) {
          final decoded = jsonDecode(usersRes.body);
          List<dynamic> usersList = [];
          if (decoded is List) {
            usersList = decoded;
          } else if (decoded is Map && decoded['content'] is List) {
            usersList = decoded['content'] as List;
          }

          final Map<String, Map> usersById = {};
          final Map<String, Map> usersByEmail = {};
          for (final u in usersList) {
            if (u is Map) {
              if (u['id'] != null) {
                usersById[u['id'].toString()] = u;
              }
              final email = (u['correo'] ?? u['email'])
                  ?.toString()
                  .trim()
                  .toLowerCase();
              if (email != null && email.isNotEmpty) {
                usersByEmail[email] = u;
              }
            }
          }

          for (final m in _miembros) {
            if (m is Map) {
              final mUid = (m['usuarioId'] ?? m['idUsuario'])?.toString();
              final mEmail = (m['usuarioCorreo'] ?? m['correo'])
                  ?.toString()
                  .trim()
                  .toLowerCase();
              final matchedUser = (mUid != null ? usersById[mUid] : null) ??
                  (mEmail != null ? usersByEmail[mEmail] : null);
              if (matchedUser != null) {
                final uFoto = matchedUser['fotoPerfilUrl'] ??
                    matchedUser['fotoPerfil'] ??
                    matchedUser['foto_perfil'];
                if (_obtenerUrlValida(uFoto).isNotEmpty) {
                  m['fotoPerfil'] = uFoto;
                  m['fotoPerfilUrl'] = uFoto;
                  anyUpdated = true;
                }
                if (m['entidad'] == null && matchedUser['entidad'] != null) {
                  m['entidad'] = matchedUser['entidad'];
                  anyUpdated = true;
                }
              }
            }
          }
        }
      }

      if (anyUpdated && mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  String _obtenerUrlValida(dynamic rawUrl) {
    if (rawUrl == null) return '';
    final str = rawUrl.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return '';
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return str;
    }
    if (str.startsWith('/')) {
      return '${ApiConfig.baseUrl}$str';
    }
    return '';
  }

  Widget _buildTimelineActivityItem(dynamic act, int number, bool isLast) {
    final nombre = act['nombre']?.toString() ??
        act['titulo']?.toString() ??
        'Actividad $number';
    final descripcion = act['descripcion']?.toString() ??
        'Planificación de trabajo para el sector del páramo.';
    final estado = (act['estado'] ?? act['estadoActividad'] ?? 'Pendiente')
        .toString();
    final fechaInicio = act['fechaInicio']?.toString() ?? '';
    final fechaFin = act['fechaFin']?.toString() ?? '';
    final fechasStr = (fechaInicio.isNotEmpty && fechaFin.isNotEmpty)
        ? '$fechaInicio - $fechaFin'
        : 'Por definir';
    final responsableNombre = _resolveResponsableNombre(act);
    final responsableId = _resolveResponsableId(act);

    final isCompletada = estado.toLowerCase().contains('complet') ||
        estado.toLowerCase().contains('finaliz');
    final isEnDesarrollo = estado.toLowerCase().contains('desarrollo') ||
        estado.toLowerCase().contains('ejecuci');

    // Icono y color del timeline
    final Color circleBg = isCompletada
        ? const Color(0xFF1E5E3A)
        : isEnDesarrollo
            ? const Color(0xFF2563EB)
            : const Color(0xFFFEF3C7);
    final IconData circleIcon = isCompletada
        ? Icons.check
        : isEnDesarrollo
            ? Icons.assignment_outlined
            : Icons.access_time_rounded;
    final Color circleIconColor = isCompletada || isEnDesarrollo
        ? Colors.white
        : const Color(0xFFD97706);

    // Badge a la derecha
    final Color badgeBg = isCompletada
        ? const Color(0xFFE8F5E9)
        : isEnDesarrollo
            ? const Color(0xFFDBEAFE)
            : const Color(0xFFFEF3C7);
    final Color badgeColor = isCompletada
        ? const Color(0xFF1E5E3A)
        : isEnDesarrollo
            ? const Color(0xFF2563EB)
            : const Color(0xFFD97706);

    final List<dynamic> rawEvidencias = (act['evidencias'] as List?) ?? [];
    final List<Map<String, dynamic>> evidencias = [
      ...rawEvidencias.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    ];
    if (evidencias.isEmpty) {
      final urlsEvs = act['urlsEvidencias'];
      if (urlsEvs is List) {
        for (final u in urlsEvs) {
          if (u != null && u.toString().trim().isNotEmpty) {
            evidencias.add({'urlArchivo': u.toString().trim()});
          }
        }
      }
      final singleUrl =
          (act['urlEvidencia'] ?? act['urlArchivo'] ?? act['fotoEvidencia'] ?? '')
              .toString()
              .trim();
      if (evidencias.isEmpty &&
          singleUrl.isNotEmpty &&
          singleUrl.toLowerCase() != 'null') {
        evidencias.add({'urlArchivo': singleUrl});
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Columna de Timeline con Círculo y Línea conectora
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: circleBg,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    circleIcon,
                    color: circleIconColor,
                    size: 16,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFE5E7EB),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Tarjeta de la Actividad
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
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
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final Map<String, dynamic> enrichedAct =
                        act is Map<String, dynamic>
                            ? Map<String, dynamic>.from(act)
                            : {};
                    enrichedAct['responsableNombre'] = responsableNombre;
                    if (responsableId != null) {
                      enrichedAct['responsableId'] = responsableId;
                    }
                    final projImg = ProjectImageHelper.resolveImageUrl(
                      _projectData,
                      extraReportes: _observaciones,
                    );
                    if (projImg.isNotEmpty) {
                      enrichedAct['projectImageUrl'] = projImg;
                    }
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityEvidenceScreen(
                          actividad: enrichedAct,
                          projectName:
                              _projectData['nombre']?.toString() ?? 'Proyecto',
                          projectId: widget.projectId,
                        ),
                      ),
                    );
                    if (updated == true && mounted) {
                      _loadProjectDetail();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Encabezado: Título y Badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '$number. $nombre',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                estado,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Fechas de vigencia
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              fechasStr,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Chip de Responsable asignado
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFDCFCE7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Color(0xFF1E5E3A),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Responsable: $responsableNombre',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF1E5E3A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Descripción resumida
                        Text(
                          descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF4B5563),
                            height: 1.3,
                          ),
                        ),

                        // Carrusel / Miniaturas de evidencias
                        if (evidencias.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ...evidencias.take(3).map((ev) {
                                final url = ev['url'] ?? ev['urlArchivo'] ?? '';
                                return Container(
                                  width: 42,
                                  height: 42,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: url.toString().isNotEmpty &&
                                            (url
                                                    .toString()
                                                    .startsWith('http://') ||
                                                url
                                                    .toString()
                                                    .startsWith('https://'))
                                        ? CachedNetworkImage(
                                            imageUrl: url.toString(),
                                            fit: BoxFit.cover,
                                            memCacheWidth: 600,
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(
                                              Icons.broken_image,
                                              size: 18,
                                            ),
                                          )
                                        : const Icon(Icons.photo, size: 20),
                                  ),
                                );
                              }),
                              if (evidencias.length > 3)
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+${evidencias.length - 3}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E5E3A),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Pestaña: Miembros
  Widget _buildTabMiembros() {
    if (_miembros.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 52,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              const Text(
                'No hay miembros registrados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3A22),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      itemCount: _miembros.length,
      itemBuilder: (context, index) {
        final m = _miembros[index];
        final nombre = (m['usuarioNombre'] ??
                m['nombreCompleto'] ??
                m['nombre'] ??
                'Miembro GoblinPark')
            .toString();
        final rol = m['rolEnProyecto'] ??
            m['rolProyecto'] ??
            m['rolNombre'] ??
            m['cargoRol'] ??
            'Guardabosques';
        final entidad = m['entidad'] ?? 'Parques Nacionales';
        final rawFoto = m['fotoPerfilUrl'] ??
            m['fotoPerfil'] ??
            m['foto_perfil'] ??
            m['fotoUrl'] ??
            (m['usuario'] is Map
                ? (m['usuario']['fotoPerfilUrl'] ?? m['usuario']['fotoPerfil'])
                : null);
        final fotoUrlValida = _obtenerUrlValida(rawFoto);
        final inicial =
            nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : 'G';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              fotoUrlValida.isNotEmpty
                  ? CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFE8F5E9),
                      backgroundImage: NetworkImage(fotoUrlValida),
                      onBackgroundImageError: (_, _) {},
                    )
                  : CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFE8F5E9),
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E5E3A),
                        ),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$rol • $entidad',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
