import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app_tesis/screens/login_screen/auth_service.dart';
import 'project_detail_screen.dart';
import 'package:app_tesis/screens/profile/notification_service.dart';
import 'package:app_tesis/screens/api_connection/api_config.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen>
    with SingleTickerProviderStateMixin {
  static const _baseUrl = '${ApiConfig.baseUrl}';
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allProjects = [];
  List<dynamic> _myProjects = [];
  List<dynamic> _filteredAll = [];
  bool _isLoadingAll = true;
  bool _isLoadingMy = true;
  String? _errorAll;
  String? _errorMy;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadAllProjects();
    _loadMyProjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredAll = _allProjects.where((p) {
        return (p['nombre'] ?? '').toLowerCase().contains(q) ||
            (p['categoriaNombre'] ?? '').toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadAllProjects() async {
    setState(() {
      _isLoadingAll = true;
      _errorAll = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/proyectos'),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        // El backend puede devolver lista directa o paginado {content: [...]}
        List<dynamic> data;
        if (body is List) {
          data = body;
        } else if (body is Map && body.containsKey('content')) {
          data = body['content'] as List;
        } else if (body is Map && body.containsKey('proyecto')) {
          data = [body]; // un solo proyecto
        } else {
          data = [];
        }

        setState(() {
          _allProjects = data;
          _filteredAll = data;
          _isLoadingAll = false;
        });
      } else {
        setState(() {
          _errorAll = 'Error ${response.statusCode}';
          _isLoadingAll = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorAll = 'Error de conexión: $e';
          _isLoadingAll = false;
        });
    }
  }

  /*Future<void> _loadAllProjects() async {
    setState(() { _isLoadingAll = true; _errorAll = null; });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/proyectos'),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _allProjects = data;
          _filteredAll = data;
          _isLoadingAll = false;
        });
      } else {
        setState(() { _errorAll = 'Error ${response.statusCode}'; _isLoadingAll = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorAll = 'Error de conexión: $e'; _isLoadingAll = false; });
    }
  }*/

  /*Future<void> _loadMyProjects() async {
    setState(() {
      _isLoadingMy = true;
      _errorMy = null;
    });
    try {
      final id = await AuthService.getUserId();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/proyectos/usuario/$id'),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _myProjects = jsonDecode(response.body) as List;
          _isLoadingMy = false;
        });
      } else {
        setState(() {
          _errorMy = 'Error ${response.statusCode}';
          _isLoadingMy = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMy = 'Error de conexión: $e';
          _isLoadingMy = false;
        });
    }
  }*/

  /*Future<void> _loadMyProjects() async {
    setState(() {
      _isLoadingMy = true;
      _errorMy = null;
    });
    try {
      final id = await AuthService.getUserId();
      final token = await AuthService.getToken();

      // Obtener membresías del usuario
      final response = await http.get(
        Uri.parse('$_baseUrl/api/proyecto-miembros/usuario/$id'),
        headers: await _headers(),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> miembros;
        if (body is List) {
          miembros = body;
        } else if (body is Map && body.containsKey('content')) {
          miembros = body['content'] as List;
        } else {
          miembros = [];
        }

        // Cada membresía tiene el proyecto anidado o solo el proyectoId
        // Construir lista de proyectos desde las membresías
        List<dynamic> proyectos = miembros
            .where((m) => m['estado'] == true) // Solo miembros activos
            .map((m) {
              // Si la membresía ya trae el objeto proyecto completo
              if (m['proyecto'] != null) return m['proyecto'];
              // Si solo trae proyectoId y proyectoNombre construimos un objeto básico
              return {
                'id': m['proyectoId'],
                'nombre': m['proyectoNombre'] ?? 'Sin nombre',
                'categoriaNombre': m['categoriaNombre'] ?? '',
                'estadoProyectoNombre': m['estadoProyectoNombre'] ?? '',
                'prioridadNombre': m['prioridadNombre'] ?? '',
                'fechaInicio': m['fechaInicio'],
                'creadoPorNombre': m['creadoPorNombre'],
              };
            })
            .toList();

        await NotificationService.updateEstados(proyectos, id!);

        setState(() {
          _myProjects = proyectos;
          _isLoadingMy = false;
        });
      } else {
        setState(() {
          _errorMy = 'Error ${response.statusCode}';
          _isLoadingMy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMy = 'Error de conexión: $e';
          _isLoadingMy = false;
        });
      }
    }
  }*/

  Future<void> _loadMyProjects() async {
    setState(() {
      _isLoadingMy = true;
      _errorMy = null;
    });
    try {
      final id = await AuthService.getUserId();

      // ── Cargar membresías del usuario ──────────────────
      final membResponse = await http.get(
        Uri.parse('$_baseUrl/api/proyecto-miembros/usuario/$id'),
        headers: await _headers(),
      );

      if (!mounted) return;
      if (membResponse.statusCode != 200) {
        setState(() {
          _errorMy = 'Error ${membResponse.statusCode}';
          _isLoadingMy = false;
        });
        return;
      }

      final membBody = jsonDecode(membResponse.body);
      List<dynamic> miembros;
      if (membBody is List) {
        miembros = membBody;
      } else if (membBody is Map && membBody.containsKey('content')) {
        miembros = membBody['content'] as List;
      } else {
        miembros = [];
      }

      // Filtrar solo membresías activas
      final miembrosActivos = miembros
          .where((m) => m['estado'] == true)
          .toList();
      final idsMembresia = miembrosActivos.map((m) => m['proyectoId']).toSet();

      if (idsMembresia.isEmpty) {
        await NotificationService.updateEstados([], id!);
        setState(() {
          _myProjects = [];
          _isLoadingMy = false;
        });
        return;
      }

      // ── Cargar todos los proyectos ─────────────────────
      final projResponse = await http.get(
        Uri.parse('$_baseUrl/api/proyectos'),
        headers: await _headers(),
      );

      if (!mounted) return;
      if (projResponse.statusCode != 200) {
        setState(() {
          _errorMy = 'Error ${projResponse.statusCode}';
          _isLoadingMy = false;
        });
        return;
      }

      final projBody = jsonDecode(projResponse.body);
      List<dynamic> todosProyectos;
      if (projBody is List) {
        todosProyectos = projBody;
      } else if (projBody is Map && projBody.containsKey('content')) {
        todosProyectos = projBody['content'] as List;
      } else {
        todosProyectos = [];
      }

      // ── 3. Cruzar por proyectoId ──────────────────────────
      final proyectos = todosProyectos
          .where((p) => idsMembresia.contains(p['id']))
          .toList();

      await NotificationService.updateEstados(proyectos, id!);

      if (mounted) {
        setState(() {
          _myProjects = proyectos;
          _isLoadingMy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMy = 'Error de conexión: $e';
          _isLoadingMy = false;
        });
      }
    }
  }

  Color _statusColor(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'en ejecución':
      case 'en ejecucion':
        return Colors.green.shade600;
      case 'en planificación':
      case 'en planificacion':
        return Colors.orange.shade600;
      case 'finalizado':
      case 'finalizada':
        return Colors.grey.shade600;
      case 'en pausa':
        return Colors.blue.shade600;
      default:
        return Colors.teal.shade600;
    }
  }

  String _categoryImage(String? categoria) {
    const map = {
      'Fauna': 'assets/images/Oso de anteojos-2.jpeg',
      'Flora': 'assets/images/Flora.jpeg',
      'Agua': 'assets/images/Agua.jpeg',
      'Aire': 'assets/images/Aire.jpeg',
      'Suelo': 'assets/images/Suelo.jpeg',
    };
    return map[categoria] ?? 'assets/images/Oso de anteojos-2.jpeg';
  }

  Widget _buildProjectCard(Map<String, dynamic> p, {bool isMine = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen categoría
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                _categoryImage(p['categoriaNombre']),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 7, 83, 11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.eco,
                    color: const Color.fromARGB(255, 7, 83, 11),
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría en negrita arriba
                  Text(
                    p['categoriaNombre'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Nombre del proyecto
                  Text(
                    'Nombre:  ${p['nombre'] ?? 'Sin nombre'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Estado:  ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        p['estadoProyectoNombre'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: _statusColor(p['estadoProyectoNombre']),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Botón según pestaña
                  if (isMine)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectDetailScreen(projectId: p['id']),
                        ),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text(
                        'Ver proyecto',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color.fromARGB(255, 7, 83, 11),
                        side: BorderSide(color: const Color.fromARGB(255, 7, 83, 11)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _requestJoin(p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 7, 83, 11),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Solicitar unirme',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Badge prioridad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(
                  p['estadoProyectoNombre'],
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                p['prioridadNombre'] ?? '',
                style: TextStyle(
                  fontSize: 10,
                  color: _statusColor(p['estadoProyectoNombre']),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*Widget _buildProjectCard(Map<String, dynamic> p, {bool isMine = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isMine
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectDetailScreen(projectId: p['id']),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícono categoría
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.green.shade50,
                child: Icon(Icons.eco, color: Colors.green.shade700, size: 24),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['nombre'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          p['categoriaNombre'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Estado:  ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          p['estadoProyectoNombre'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: _statusColor(p['estadoProyectoNombre']),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (p['fechaInicio'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Del: ${p['fechaInicio']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (isMine)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProjectDetailScreen(projectId: p['id']),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text(
                          'Ver proyecto',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade400),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    else
                      Text(
                        p['creadoPorNombre'] != null
                            ? 'Creado por: ${p['creadoPorNombre']}'
                            : '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
              ),

              // Prioridad badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(
                    p['estadoProyectoNombre'],
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p['prioridadNombre'] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: _statusColor(p['estadoProyectoNombre']),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }*/

  Widget _buildList(
    List<dynamic> list,
    bool isLoading,
    String? error,
    VoidCallback onRetry, {
    bool isMine = false,
  }) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(error, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              isMine
                  ? 'No perteneces a ningún proyecto'
                  : 'No hay proyectos disponibles',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: isMine ? _loadMyProjects : _loadAllProjects,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: list.length,
        itemBuilder: (_, i) => _buildProjectCard(
          Map<String, dynamic>.from(list[i]),
          isMine: isMine,
        ),
      ),
    );
  }

  Future<void> _requestJoin(Map<String, dynamic> proyecto) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.send_rounded, color: const Color.fromARGB(255, 7, 83, 11), size: 48),
            const SizedBox(height: 12),
            Text(
              '¿Solicitar unirte a\n"${proyecto['nombre']}"?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 7, 83, 11),
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final token = await AuthService.getToken();
      const mensaje = 'Quiero participar en este proyecto ambiental';

      final response = await http.post(
        Uri.parse('$_baseUrl/api/solicitudes-proyecto'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'proyectoId': proyecto['id'], 'mensaje': mensaje}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Guardar notificación local
        final userId = await AuthService.getUserId();
        await NotificationService.saveSolicitud(
          usuarioId: userId!,
          proyectoId: proyecto['id'],
          proyectoNombre: proyecto['nombre'] ?? '',
          mensaje: mensaje,
        );

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: const Color.fromARGB(255, 7, 83, 11),
                  size: 64,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu solicitud ha sido enviada con éxito. Espera que el administrador te acepte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadMyProjects();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar solicitud: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  /*Future<void> _requestJoin(Map<String, dynamic> proyecto) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/Check.png', width: 80),
            const SizedBox(height: 12),
            Text(
              '¿Solicitar unirte a\n"${proyecto['nombre']}"?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();

      final response = await http.post(
        Uri.parse('$_baseUrl/api/proyecto-miembros'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'proyectoId': proyecto['id'],
          'usuarioId': userId,
          'rolEnProyecto': 'USER',
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade600,
                  size: 64,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu solicitud ha sido enviada con éxito. Espera que el administrador te acepte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadMyProjects();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar solicitud: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar proyecto...',
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade500,
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 12,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color.fromARGB(255, 7, 83, 11)),
            onPressed: () {
              _loadAllProjects();
              _loadMyProjects();
            },
            tooltip: 'Actualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color.fromARGB(255, 7, 83, 11),
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: Color.fromARGB(255, 7, 83, 11),
          tabs: const [
            Tab(text: 'Proyectos'),
            Tab(text: 'Mis proyectos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_filteredAll, _isLoadingAll, _errorAll, _loadAllProjects),
          _buildList(
            _myProjects,
            _isLoadingMy,
            _errorMy,
            _loadMyProjects,
            isMine: true,
          ),
        ],
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
//import 'package:app_tesis/screens/projects/view_project.dart';
//import 'package:app_tesis/screens/projects/application_project.dart';

// Modelo simple de proyecto
class Project {
  final String id;
  final String category;
  final String name;
  final String status;
  final String imageUrl;
  bool hasPendingRequest;

  Project({
    required this.id,
    required this.category,
    required this.name,
    required this.status,
    required this.imageUrl,
    this.hasPendingRequest = false,
  });
}

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Proyectos de ejemplo (reemplaza con tus datos reales)
  final List<Project> _allProjects = [
    Project(
      id: '1',
      category: 'Fauna',
      name: 'Guardianes del puma',
      status: 'En ejecución',
      imageUrl: '',
    ),
    Project(
      id: '2',
      category: 'Agua',
      name: 'Conservación río colima',
      status: 'En planificación',
      imageUrl: '',
    ),
    Project(
      id: '3',
      category: 'Flora',
      name: 'Salvemos el árbol del polylepis',
      status: 'Finalizada',
      imageUrl: '',
    ),
  ];

  // Proyectos donde el usuario ya tiene solicitud enviada
  final List<Project> _myProjects = [];

  List<Project> _filteredProjects = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filteredProjects = List.from(_allProjects);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filteredProjects = _allProjects.where((p) {
        return p.name.toLowerCase().contains(_searchQuery) ||
            p.category.toLowerCase().contains(_searchQuery);
      }).toList();
    });
  }

  // Muestra diálogo de confirmación de solicitud
  Future<void> _requestJoin(Project project) async {
    // Navegar a la pantalla de solicitud (como en tu código original)
    // O mostrar un bottom sheet / diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _JoinRequestDialog(projectName: project.name),
    );

    if (confirmed == true) {
      setState(() {
        project.hasPendingRequest = true;
        if (!_myProjects.any((p) => p.id == project.id)) {
          _myProjects.add(project);
        }
      });

      // Mostrar confirmación de éxito
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => const _SuccessDialog(),
        );
      }
    }
  }

  // Eliminar solicitud con confirmación
  Future<void> _cancelRequest(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _DeleteRequestDialog(),
    );

    if (confirmed == true) {
      setState(() {
        project.hasPendingRequest = false;
        _myProjects.removeWhere((p) => p.id == project.id);
      });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en ejecución':
        return Colors.green.shade600;
      case 'en planificación':
        return Colors.orange.shade600;
      case 'finalizada':
        return Colors.grey.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  Widget _buildProjectCard(Project project, {bool isMine = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen / Avatar del proyecto
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: project.imageUrl.isNotEmpty
                  ? Image.network(
                      project.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      color: Colors.green.shade100,
                      child: Icon(Icons.eco,
                          color: Colors.green.shade700, size: 28),
                    ),
            ),
            const SizedBox(width: 12),

            // Info del proyecto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Nombre:  ${project.name}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Estado:  ',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(
                        project.status,
                        style: TextStyle(
                          fontSize: 12,
                          color: _statusColor(project.status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Botón de acción
                  if (isMine || project.hasPendingRequest)
                    OutlinedButton(
                      onPressed: () => _cancelRequest(project),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Eliminar solicitud',
                          style: TextStyle(fontSize: 12)),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _requestJoin(project),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Solicitar unirme',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar proyecto...',
            prefixIcon:
                Icon(Icons.search, color: Colors.grey.shade500, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green.shade700,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: Colors.green.shade700,
          tabs: const [
            Tab(text: 'Proyectos'),
            Tab(text: 'Mis proyectos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Todos los proyectos
          _filteredProjects.isEmpty
              ? const Center(child: Text('No se encontraron proyectos'))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: _filteredProjects.length,
                  itemBuilder: (ctx, i) =>
                      _buildProjectCard(_filteredProjects[i]),
                ),

          // Tab 2: Mis proyectos (donde tengo solicitud)
          _myProjects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No tienes solicitudes enviadas',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: _myProjects.length,
                  itemBuilder: (ctx, i) =>
                      _buildProjectCard(_myProjects[i], isMine: true),
                ),
        ],
      ),
    );
  }
}

// ─── Diálogos ───────────────────────────────────────────────────────────────

class _JoinRequestDialog extends StatelessWidget {
  final String projectName;
  const _JoinRequestDialog({required this.projectName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/Check.png', width: 110,),
          //Icon(Icons.send_rounded, color: Colors.green.shade600, size: 48),
          const SizedBox(height: 12),
          Text(
            '¿Solicitar unirte a\n"$projectName"?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white),
          child: const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              color: Colors.green.shade600, size: 64),
          const SizedBox(height: 12),
          const Text(
            'Tu solicitud ha sido enviada con éxito. Espera que el administrador te acepte.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

class _DeleteRequestDialog extends StatelessWidget {
  const _DeleteRequestDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_rounded, color: Colors.red.shade600, size: 64),
          const SizedBox(height: 12),
          const Text(
            '¿Quieres eliminar la solicitud?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white),
          child: const Text('Sí, eliminar'),
        ),
      ],
    );
  }
}
/*import 'package:flutter/material.dart';
import 'package:app_tesis/screens/projects/view_project.dart';
//import 'package:app_tesis/screens/projects/state_application.dart';
import 'package:app_tesis/screens/projects/application_project.dart';

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Proyectos")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(
              child: const Text("Ver proyectos creados"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ViewProjectScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Solicitar unirse a proyecto"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ApplicationProjectScreeen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}*/
*/
