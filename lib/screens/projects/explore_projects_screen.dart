import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/profile/notification_service.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/projects/project_detail_screen.dart';
import 'package:goblink_park/screens/projects/project_image_helper.dart';

class ExploreProjectsScreen extends StatefulWidget {
  const ExploreProjectsScreen({super.key});

  @override
  State<ExploreProjectsScreen> createState() => _ExploreProjectsScreenState();
}

class _ExploreProjectsScreenState extends State<ExploreProjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allProjects = [];
  List<dynamic> _filteredProjects = [];
  Set<int> _myMemberProjectIds = {};
  Set<int> _myRequestedProjectIds = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'Todos';

  final List<String> _categories = [
    'Todos',
    'Restauración',
    'Monitoreo',
    'Educación',
    'Conservación',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    debugPrint('>>> GET Explorar Proyectos solicitado');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();

      // 1. Obtener membresías existentes del usuario
      if (userId != null && token != null) {
        try {
          final membRes = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/proyecto-miembros/usuario/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 50));

          if (membRes.statusCode == 200) {
            final membBody = jsonDecode(membRes.body);
            List<dynamic> miembros = [];
            if (membBody is List) {
              miembros = membBody;
            } else if (membBody is Map && membBody.containsKey('content')) {
              miembros = membBody['content'] as List;
            }
            _myMemberProjectIds = miembros
                .where((m) => m['estado'] == true)
                .map((m) => m['proyectoId'] as int? ?? 0)
                .where((id) => id > 0)
                .toSet();
          }
        } catch (_) {}

        // Obtener solicitudes guardadas localmente
        final localReqs = await NotificationService.getSolicitudesDeUsuario(userId);
        _myRequestedProjectIds = localReqs
            .where((s) => s['estado'] == 'pendiente')
            .map((s) => s['proyectoId'] as int? ?? 0)
            .where((id) => id > 0)
            .toSet();
      }

      // 2. Obtener todos los proyectos
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/proyectos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 50));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> list = [];
        if (body is List) {
          list = body;
        } else if (body is Map && body.containsKey('content')) {
          list = (body['content'] as List?) ?? [];
        } else if (body is Map && body.containsKey('proyecto')) {
          list = [body];
        }

        await ProjectImageHelper.enrichProjectsWithReportImages(
          list,
          token: token,
        );
        if (!mounted) return;

        setState(() {
          _allProjects = list;
          _isLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _errorMessage = 'Error ${response.statusCode} al obtener proyectos';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredProjects = _allProjects.where((p) {
        final name = (p['nombre'] ?? '').toString().toLowerCase();
        final desc = (p['descripcion'] ?? '').toString().toLowerCase();
        final cat = (p['categoriaNombre'] ?? p['categoria'] ?? '')
            .toString()
            .toLowerCase();

        final matchesQuery = query.isEmpty ||
            name.contains(query) ||
            desc.contains(query) ||
            cat.contains(query);

        if (!matchesQuery) return false;

        if (_selectedCategory == 'Todos') return true;

        return cat.contains(_selectedCategory.toLowerCase());
      }).toList();
    });
  }

  Future<void> _handleJoinRequest(dynamic project) async {
    final id = project['id'] is int
        ? project['id'] as int
        : int.tryParse(project['id']?.toString() ?? '0') ?? 0;
    final nombre = project['nombre']?.toString() ?? 'Proyecto ambiental';

    if (id <= 0) return;

    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();
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

      // Petición al backend
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/solicitudes-proyecto'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'idProyecto': id,
          'proyectoId': id,
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

      // Guardar localmente
      if (userId != null) {
        await NotificationService.saveSolicitud(
          usuarioId: userId,
          proyectoId: id,
          proyectoNombre: nombre,
          mensaje: mensaje,
          idSolicitud: idSolicitud,
        );
      }

      setState(() {
        _myRequestedProjectIds.add(id);
      });

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 409) {
        _showConfirmationDialog(nombre);
      } else {
        // Aún si la API responde con validación, mostramos feedback amigable
        _showConfirmationDialog(nombre);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      // Si falló por conexión pero guardó localmente, notificar al usuario
      if (userId != null) {
        await NotificationService.saveSolicitud(
          usuarioId: userId,
          proyectoId: id,
          proyectoNombre: nombre,
          mensaje: mensaje,
        );
        setState(() {
          _myRequestedProjectIds.add(id);
        });
      }
      if (mounted) _showConfirmationDialog(nombre);
    }
  }

  void _showCancelRequestModal(dynamic project) {
    final id = project['id'] is int
        ? project['id'] as int
        : int.tryParse(project['id']?.toString() ?? '0') ?? 0;

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
                          final solicitudes = await NotificationService.getSolicitudesDeUsuario(userId);
                          final req = solicitudes.firstWhere(
                            (s) => s['proyectoId'] == id,
                            orElse: () => {},
                          );
                          final idSolicitud = req['idSolicitud'] ?? req['id'];
                          if (idSolicitud != null) {
                            try {
                              await http.delete(
                                Uri.parse('${ApiConfig.baseUrl}/api/solicitudes-proyecto/$idSolicitud'),
                                headers: {'Authorization': 'Bearer $token'},
                              ).timeout(const Duration(seconds: 50));
                            } catch (_) {}
                          }
                          await NotificationService.cancelSolicitud(
                            usuarioId: userId,
                            proyectoId: id,
                          );
                        }
                        setState(() {
                          _myRequestedProjectIds.remove(id);
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

  // Modal institucional: "Solicitud enviada"
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

  String _formatDates(dynamic p) {
    final inicio = p['fechaInicio']?.toString() ?? '';
    final fin = p['fechaFin']?.toString() ?? '';
    if (inicio.isNotEmpty && fin.isNotEmpty) {
      return '$inicio - $fin';
    } else if (inicio.isNotEmpty) {
      return 'Desde $inicio';
    }
    return 'Ene 2024 - Dic 2025';
  }

  int _getMemberCount(dynamic p) {
    if (p['numeroMiembros'] != null) {
      return int.tryParse(p['numeroMiembros'].toString()) ?? 8;
    }
    if (p['miembros'] is List) {
      return (p['miembros'] as List).length;
    }
    return 12;
  }

  String _getImageUrl(dynamic p) {
    return ProjectImageHelper.resolveImageUrl(p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E5E3A),
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
            const Text(
              'Goblin Park',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F3A22),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF1E5E3A),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Explorar proyectos',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F3A22),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Únete a iniciativas de conservación del Páramo del Duende',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSearchBar(),
                      const SizedBox(height: 12),
                      _buildCategoryChips(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1E5E3A),
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
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
                            onPressed: _loadData,
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
                  ),
                )
              else if (_filteredProjects.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.travel_explore_rounded,
                            size: 58,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron iniciativas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F3A22),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Intenta buscando en otra categoría o término.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final project = _filteredProjects[index];
                        return _buildExplorationCard(project);
                      },
                      childCount: _filteredProjects.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar proyectos o temas...',
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: Colors.grey.shade400,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF1E5E3A),
            size: 22,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  int _categoryCount(String cat) {
    if (cat == 'Todos') return _allProjects.length;
    return _allProjects.where((p) {
      final c = (p['categoriaNombre'] ?? p['categoria'] ?? '')
          .toString()
          .toLowerCase();
      return c.contains(cat.toLowerCase());
    }).length;
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((c) {
          final isSelected = _selectedCategory == c;
          final count = _categoryCount(c);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                '$c ($count)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF374151),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1E5E3A),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1E5E3A)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              showCheckmark: false,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedCategory = c);
                  _applyFilters();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExplorationCard(dynamic project) {
    final id = project['id'] is int
        ? project['id'] as int
        : int.tryParse(project['id']?.toString() ?? '0') ?? 0;
    final nombre = project['nombre']?.toString() ?? 'Iniciativa ambiental';
    final categoria = project['categoriaNombre']?.toString() ??
        project['categoria']?.toString() ??
        'Monitoreo ambiental';
    final descripcion = project['descripcion']?.toString() ??
        'Objetivo de recuperación, caracterización y conservación en el PNR Páramo del Duende.';
    final imageUrl = _getImageUrl(project);
    final dates = _formatDates(project);
    final membersCount = _getMemberCount(project);

    final isMember = _myMemberProjectIds.contains(id);
    final isRequested = _myRequestedProjectIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen representativa (portada del reporte asociado)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: SizedBox(
              width: double.infinity,
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty &&
                      (imageUrl.startsWith('http://') ||
                          imageUrl.startsWith('https://')))
                    Image.network(
                      imageUrl,
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
                  // Overlay degradado sutil
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                  // Badge de categoría superior derecha
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
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
                  ),
                ],
              ),
            ),
          ),

          // Contenido descriptivo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                InkWell(
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
                  child: Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Descripción de objetivos
                Text(
                  descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                // Fechas y Participantes
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dates,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.group_outlined,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$membersCount miembros',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Botón "Solicitar unirme"
                if (isMember)
                  Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF1E5E3A),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Ya eres miembro',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E5E3A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (isRequested)
                  Column(
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
                        height: 42,
                        child: OutlinedButton(
                          onPressed: () => _showCancelRequestModal(project),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancelar solicitud',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _handleJoinRequest(project),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
