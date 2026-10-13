import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/projects/explore_projects_screen.dart';
import 'package:goblink_park/screens/projects/my_projects_screen.dart';
import 'package:goblink_park/screens/projects/project_detail_screen.dart';
import 'package:goblink_park/screens/projects/project_image_helper.dart';
import 'package:goblink_park/widgets/notification_bell_button.dart';

class ProjectsHomeScreen extends StatefulWidget {
  const ProjectsHomeScreen({super.key});

  @override
  State<ProjectsHomeScreen> createState() => _ProjectsHomeScreenState();
}

class _ProjectsHomeScreenState extends State<ProjectsHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allProjects = [];
  List<dynamic> _filteredProjects = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'Todos'; // 'Todos', 'Activos', 'Finalizados'

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    debugPrint('>>> GET Proyectos solicitado');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
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
          _errorMessage = 'Error ${response.statusCode} al cargar proyectos';
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
        final cat = (p['categoriaNombre'] ?? p['categoria'] ?? '')
            .toString()
            .toLowerCase();
        final matchesQuery = query.isEmpty ||
            name.contains(query) ||
            cat.contains(query);

        if (!matchesQuery) return false;

        final estado = (p['estadoProyectoNombre'] ?? p['estado'] ?? '')
            .toString()
            .toLowerCase();
        if (_selectedFilter == 'Activos') {
          return estado.contains('activo') ||
              estado.contains('ejecuci') ||
              estado.contains('planific') ||
              estado.isEmpty;
        } else if (_selectedFilter == 'Finalizados') {
          return estado.contains('finaliz') ||
              estado.contains('terminad') ||
              estado.contains('completa');
        }
        return true;
      }).toList();
    });
  }

  int get _todosCount => _allProjects.length;

  int get _activosCount => _allProjects.where((p) {
        final estado = (p['estadoProyectoNombre'] ?? p['estado'] ?? '')
            .toString()
            .toLowerCase();
        return estado.contains('activo') ||
            estado.contains('ejecuci') ||
            estado.contains('planific') ||
            estado.isEmpty;
      }).length;

  int get _finalizadosCount => _allProjects.where((p) {
        final estado = (p['estadoProyectoNombre'] ?? p['estado'] ?? '')
            .toString()
            .toLowerCase();
        return estado.contains('finaliz') ||
            estado.contains('terminad') ||
            estado.contains('completa');
      }).length;

  double _getProjectProgress(dynamic p) {
    if (p['porcentajeAvance'] != null) {
      final v = double.tryParse(p['porcentajeAvance'].toString());
      if (v != null) return (v / 100.0).clamp(0.0, 1.0);
    }
    if (p['avance'] != null) {
      final v = double.tryParse(p['avance'].toString());
      if (v != null) return (v / 100.0).clamp(0.0, 1.0);
    }
    final estado = (p['estadoProyectoNombre'] ?? p['estado'] ?? '')
        .toString()
        .toLowerCase();
    if (estado.contains('finaliz') || estado.contains('completa')) return 1.0;
    if (estado.contains('ejecuci')) return 0.65;
    if (estado.contains('planific')) return 0.25;
    return 0.45;
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

  String _getImageUrl(dynamic p) {
    return ProjectImageHelper.resolveImageUrl(p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProjects,
          color: const Color(0xFF1E5E3A),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Institucional
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstitutionalHeader(),
                      const SizedBox(height: 16),
                      _buildTitleSection(),
                      const SizedBox(height: 14),
                      _buildQuickActionButtons(),
                      const SizedBox(height: 14),
                      _buildSearchBar(),
                      const SizedBox(height: 12),
                      _buildFilterChips(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Contenido principal: listado o estados
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
                            Icons.cloud_off_rounded,
                            size: 54,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadProjects,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reintentar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E5E3A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
                            Icons.folder_open_rounded,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron proyectos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F3A22),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Prueba cambiando el término de búsqueda o el filtro.',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final project = _filteredProjects[index];
                        return _buildProjectCard(project);
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

  // Header institucional con logo y notificaciones
  Widget _buildInstitutionalHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/Logo verde.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.park,
                color: Color(0xFF1E5E3A),
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Goblin Park',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'PNR Páramo del Duende',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFA3B899) : const Color(0xFF1E5E3A),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBellButton(size: 24),
        ],
      ),
    );
  }

  // Título de la vista
  Widget _buildTitleSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proyectos',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Iniciativas para la conservación del páramo',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // Accesos rápidos entre Explorar y Mis Proyectos
  Widget _buildQuickActionButtons() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExploreProjectsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B2620) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0x3352B788) : const Color(0xFFC8E6C9),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.explore_outlined,
                    color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Explorar proyectos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF0F3A22),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyProjectsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_shared_outlined,
                    color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mis proyectos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Buscador de proyectos
  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar proyectos o categorías...',
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade400,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
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

  // Chips de filtro
  Widget _buildFilterChips() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filters = [
      {'key': 'Todos', 'label': 'Todos ($_todosCount)'},
      {'key': 'Activos', 'label': 'Activos ($_activosCount)'},
      {'key': 'Finalizados', 'label': 'Finalizados ($_finalizadosCount)'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final key = item['key']!;
          final label = item['label']!;
          final isSelected = _selectedFilter == key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFE8F5E9) : const Color(0xFF374151)),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1E5E3A),
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1E5E3A)
                      : (isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB)),
                ),
              ),
              showCheckmark: false,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedFilter = key);
                  _applyFilters();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Tarjeta de proyecto institucional
  Widget _buildProjectCard(dynamic project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final id = project['id'] is int
        ? project['id']
        : int.tryParse(project['id']?.toString() ?? '0') ?? 0;
    final nombre = project['nombre']?.toString() ?? 'Proyecto sin título';
    final categoria = project['categoriaNombre']?.toString() ??
        project['categoria']?.toString() ??
        'Conservación';
    final estadoRaw = (project['estadoProyectoNombre'] ??
            project['estado'] ??
            'Activo')
        .toString();
    final isFinalizado = estadoRaw.toLowerCase().contains('finaliz') ||
        estadoRaw.toLowerCase().contains('completa');
    final progress = _getProjectProgress(project);
    final progressPercent = (progress * 100).toInt();
    final dateRange = _formatDates(project);
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
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(
                  projectId: id,
                  initialProject: project is Map<String, dynamic> ? project : null,
                ),
              ),
            );
            if (mounted) setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Imagen destacada al 100% del contenedor cuadrado
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 75,
                    height: 75,
                    child: Image.network(
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
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Información central
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge de estado
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isFinalizado
                                  ? (isDark ? const Color(0xFF263238) : const Color(0xFFECEFF1))
                                  : (isDark ? const Color(0xFF1B2620) : const Color(0xFFE8F5E9)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isFinalizado ? 'Finalizado' : 'Activo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isFinalizado
                                    ? (isDark ? const Color(0xFF90A4AE) : const Color(0xFF546E7A))
                                    : (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A)),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            dateRange,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Título del proyecto
                      Text(
                        nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Categoría ambiental
                      Row(
                        children: [
                          Icon(
                            Icons.eco_outlined,
                            size: 13,
                            color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              categoria,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Barra de progreso y porcentaje
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: isDark
                                    ? const Color(0xFF2D3748)
                                    : const Color(0xFFE5E7EB),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isFinalizado
                                      ? (isDark ? const Color(0xFF90A4AE) : const Color(0xFF546E7A))
                                      : (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$progressPercent%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isFinalizado
                                  ? (isDark ? const Color(0xFF90A4AE) : const Color(0xFF546E7A))
                                  : (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
