import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'observation_detail_screen.dart';
import 'observation_edit_screen.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';

class MyObservationsScreen extends StatefulWidget {
  const MyObservationsScreen({super.key});

  @override
  State<MyObservationsScreen> createState() => _MyObservationsScreenState();
}

class _MyObservationsScreenState extends State<MyObservationsScreen> {
  static const _baseUrl = '${ApiConfig.baseUrl}';

  List<dynamic> _observations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadObservations();
  }

  Future<void> _loadObservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await AuthService.getToken();
      final id = await AuthService.getUserId();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/reportes/usuario/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> all;
        if (body is List) {
          all = body;
        } else if (body is Map && body.containsKey('content')) {
          all = body['content'] as List;
        } else {
          all = [];
        }
        setState(() {
          _observations = all;
          _isLoading = false;
        });
      } else {
        // Fallback: GET /api/reportes y filtrar localmente
        final r2 = await http.get(
          Uri.parse('$_baseUrl/api/reportes'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        if (!mounted) return;
        if (r2.statusCode == 200) {
          final body2 = jsonDecode(r2.body);
          List<dynamic> all;
          if (body2 is List) {
            all = body2;
          } else if (body2 is Map && body2.containsKey('content')) {
            all = body2['content'] as List;
          } else {
            all = [];
          }
          setState(() {
            _observations = all.where((r) => r['usuarioId'] == id).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Error ${r2.statusCode} al cargar observaciones';
            _isLoading = false;
          });
        }
      }
      /*if (response.statusCode == 200) {
        final all = jsonDecode(response.body) as List;
        setState(() {
          _observations = all;
          _isLoading = false;
        });
      } else {
        // Fallback: GET /api/reportes y filtrar localmente
        final r2 = await http.get(
          Uri.parse('$_baseUrl/api/reportes'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        if (!mounted) return;
        if (r2.statusCode == 200) {
          final all = jsonDecode(r2.body) as List;
          setState(() {
            _observations = all
                .where((r) => r['usuarioId'] == id)
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Error ${r2.statusCode} al cargar observaciones';
            _isLoading = false;
          });
        }
      }*/
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ── Agrupar por categoría ──────────────────────────────────
  Map<String, List<dynamic>> get _grouped {
    final Map<String, List<dynamic>> map = {};
    for (final obs in _observations) {
      final cat = obs['categoriaNombre'] ?? 'Sin categoría';
      map.putIfAbsent(cat, () => []).add(obs);
    }
    return map;
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

  String _timeAgo(String? fechaStr) {
    if (fechaStr == null || fechaStr.trim().isEmpty) {
      return '';
    }

    try {
      DateTime fecha = DateTime.parse(fechaStr);

      // Si la fecha viene sin información de zona horaria,
      // la interpretamos como hora local.
      if (!fechaStr.contains('Z') &&
          !fechaStr.contains('+') &&
          !RegExp(r'-\d{2}:\d{2}$').hasMatch(fechaStr)) {
        fecha = DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          fecha.hour,
          fecha.minute,
          fecha.second,
          fecha.millisecond,
          fecha.microsecond,
        );
      }

      final ahora = DateTime.now();
      final diff = ahora.difference(fecha);

      if (diff.isNegative) {
        return 'Hace unos momentos';
      }

      if (diff.inSeconds < 60) {
        return 'Hace unos segundos';
      }

      if (diff.inMinutes < 60) {
        final minutos = diff.inMinutes;
        return minutos == 1 ? 'Hace 1 minuto' : 'Hace $minutos minutos';
      }

      if (diff.inHours < 24) {
        final horas = diff.inHours;
        return horas == 1 ? 'Hace 1 hora' : 'Hace $horas horas';
      }

      if (diff.inDays < 30) {
        final dias = diff.inDays;
        return dias == 1 ? 'Hace 1 día' : 'Hace $dias días';
      }

      return '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/'
          '${fecha.year}';
    } catch (e) {
      debugPrint('Error procesando fecha: $fechaStr -> $e');
      return fechaStr.length >= 10 ? fechaStr.substring(0, 10) : fechaStr;
    }
  }

  /*String _timeAgo(String? fechaStr) {
    if (fechaStr == null) return '';
    try {
      final fecha = DateTime.parse(fechaStr);
      final diff = DateTime.now().difference(fecha);
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} minutos';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
      return 'Hace ${diff.inDays} días';
    } catch (_) {
      return fechaStr.substring(0, 10);
    }
  }*/

  Future<void> _deleteObservation(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red.shade600, size: 56),
            const SizedBox(height: 12),
            const Text(
              '¿Quieres eliminar esta observación?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/reportes/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observación eliminada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadObservations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _shareObservation(Map<String, dynamic> obs) {
    Share.share(
      '📍 Observación: ${obs['titulo']}\n'
      '🌿 Categoría: ${obs['categoriaNombre']}\n'
      '⚑ Prioridad: ${obs['prioridadNombre']}\n'
      '📝 ${obs['descripcion'] ?? ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Ver Observaciones',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadObservations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadObservations,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : _observations.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aún no tienes observaciones',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadObservations,
              child: ListView(
                children: _grouped.entries.map((entry) {
                  final categoria = entry.key;
                  final items = entry.value;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundImage: AssetImage(_categoryImage(categoria)),
                      ),

                      title: Text(
                        categoria,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      subtitle: Text("${items.length} observaciones"),

                      children: items.map((obs) {
                        return _ObservationTile(
                          obs: obs,
                          categoria: categoria,
                          imageAsset: _categoryImage(categoria),
                          timeAgo: _timeAgo(
                            obs['createdAt'] ?? obs['fechaEvento'],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ObservationDetailScreen(
                                obs: Map<String, dynamic>.from(obs),
                              ),
                            ),
                          ),
                          onEdit: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ObservationEditScreen(
                                  obs: Map<String, dynamic>.from(obs),
                                ),
                              ),
                            );
                            _loadObservations();
                          },
                          onDelete: () => _deleteObservation(obs['id'] as int),
                          onShare: () =>
                              _shareObservation(Map<String, dynamic>.from(obs)),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
              /*child: ListView(
                children: _grouped.entries.map((entry) {
                  final categoria = entry.key;
                  final items = entry.value;
                  return Column(
                    children: items.map((obs) {
                      return _ObservationTile(
                        obs: obs,
                        categoria: categoria,
                        imageAsset: _categoryImage(categoria),
                        timeAgo: _timeAgo(
                          obs['fechaEvento'] ?? obs['createdAt'],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ObservationDetailScreen(
                              obs: Map<String, dynamic>.from(obs),
                            ),
                          ),
                        ),
                        onEdit: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ObservationEditScreen(
                                obs: Map<String, dynamic>.from(obs),
                              ),
                            ),
                          );
                          _loadObservations();
                        },
                        onDelete: () => _deleteObservation(obs['id'] as int),
                        onShare: () =>
                            _shareObservation(Map<String, dynamic>.from(obs)),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),*/
            ),
    );
  }
}

// ─── Tile de observación ─────────────────────────────────────────────────────

class _ObservationTile extends StatelessWidget {
  final Map<String, dynamic> obs;
  final String categoria;
  final String imageAsset;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _ObservationTile({
    required this.obs,
    required this.categoria,
    required this.imageAsset,
    required this.timeAgo,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            // Info izquierda
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoria,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

            // Menú de acciones
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: Colors.grey.shade400,
                size: 20,
              ),
              onSelected: (v) {
                if (v == 'editar') onEdit();
                if (v == 'borrar') onDelete();
                if (v == 'compartir') onShare();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'borrar',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'compartir',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Compartir'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),

            // Imagen categoría
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imageAsset,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.eco,
                    color: Colors.green.shade700,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:app_tesis/screens/login_screen/auth_service.dart';
import 'observation_detail_screen.dart';
import 'observation_edit_screen.dart';

class MyObservationsScreen extends StatefulWidget {
  const MyObservationsScreen({super.key});

  @override
  State<MyObservationsScreen> createState() => _MyObservationsScreenState();
}

class _MyObservationsScreenState extends State<MyObservationsScreen> {
  static const _baseUrl = 'http://10.0.2.2:8080';

  List<dynamic> _observations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadObservations();
  }

  Future<void> _loadObservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await AuthService.getToken();
      final id = await AuthService.getUserId();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/reportes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      /*if (response.statusCode == 200) {
        final all = jsonDecode(response.body) as List;
        // Filtrar solo los del usuario actual
        setState(() {
          _observations = all.where((r) => r['usuarioId'] == id).toList();
          _isLoading = false;
        });
      if (response.statusCode == 200) {
        debugPrint("BODY: ${response.body}");

        final decoded = jsonDecode(response.body);

        debugPrint("TIPO: ${decoded.runtimeType}");

        final all = decoded as List;

        setState(() {
          _observations = all.where((r) => r['usuarioId'] == id).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Error ${response.statusCode} al cargar observaciones';
          _isLoading = false;
        });
      }*/
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final all = decoded['content'] as List;

        setState(() {
          _observations = all.where((r) => r['usuarioId'] == id).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Error ${response.statusCode} al cargar observaciones';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  /*Future<void> _loadObservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await AuthService.getToken();
      final id = await AuthService.getUserId();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/reportes/usuario/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _observations = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error ${response.statusCode} al cargar observaciones';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }*/

  // ── Agrupar por categoría ──────────────────────────────────
  Map<String, List<dynamic>> get _groupedObservations {
    final Map<String, List<dynamic>> grouped = {};
    for (final obs in _observations) {
      final categoria = obs['categoriaNombre'] ?? 'Sin categoría';
      grouped.putIfAbsent(categoria, () => []).add(obs);
    }
    return grouped;
  }

  // ── Eliminar ───────────────────────────────────────────────
  Future<void> _deleteObservation(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red.shade600, size: 56),
            const SizedBox(height: 12),
            const Text(
              '¿Quieres borrar la observación?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, borrar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/reportes/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observación eliminada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadObservations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar'),
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

  // ── Compartir ──────────────────────────────────────────────
  void _shareObservation(Map<String, dynamic> obs) {
    final texto =
        '📍 Observación: ${obs['titulo']}\n'
        '🌿 Categoría: ${obs['categoriaNombre']}\n'
        '⚑ Prioridad: ${obs['prioridadNombre']}\n'
        '📝 ${obs['descripcion'] ?? ''}\n'
        '📌 ${obs['latitud']?.toStringAsFixed(4)}, '
        '${obs['longitud']?.toStringAsFixed(4)}';
    Share.share(texto);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Ver Observaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadObservations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadObservations,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : _observations.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aún no tienes observaciones',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadObservations,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                children: _groupedObservations.entries
                    .map(
                      (entry) => _CategorySection(
                        categoria: entry.key,
                        observations: entry.value,
                        categoryImage: _categoryImage(entry.key),
                        onDelete: _deleteObservation,
                        onShare: _shareObservation,
                        onRefresh: _loadObservations,
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

// ─── Sección por categoría ───────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String categoria;
  final List<dynamic> observations;
  final String categoryImage;
  final Function(int) onDelete;
  final Function(Map<String, dynamic>) onShare;
  final VoidCallback onRefresh;

  const _CategorySection({
    required this.categoria,
    required this.observations,
    required this.categoryImage,
    required this.onDelete,
    required this.onShare,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado de categoría ──────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  categoryImage,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                categoria,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // ── Cards de observaciones ───────────────────────
        ...observations.map(
          (obs) => _ObservationCard(
            obs: obs,
            categoryImage: categoryImage,
            onDelete: onDelete,
            onShare: onShare,
            onRefresh: onRefresh,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Card de observación ─────────────────────────────────────────────────────

class _ObservationCard extends StatelessWidget {
  final Map<String, dynamic> obs;
  final String categoryImage;
  final Function(int) onDelete;
  final Function(Map<String, dynamic>) onShare;
  final VoidCallback onRefresh;

  const _ObservationCard({
    required this.obs,
    required this.categoryImage,
    required this.onDelete,
    required this.onShare,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ObservationDetailScreen(obs: obs)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Imagen categoría ─────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  categoryImage,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // ── Info ─────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obs['titulo'] ?? 'Sin título',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      obs['descripcion'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 11,
                          color: Colors.grey.shade400,
                        ),
                        Text(
                          '${obs['latitud']?.toStringAsFixed(3)}, '
                          '${obs['longitud']?.toStringAsFixed(3)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Acciones ─────────────────────────────
              Column(
                children: [
                  // Editar
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Colors.blue.shade400,
                      size: 20,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ObservationEditScreen(obs: obs),
                        ),
                      );
                      onRefresh();
                    },
                  ),
                  // Borrar
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                    onPressed: () => onDelete(obs['id'] as int),
                  ),
                  // Compartir
                  IconButton(
                    icon: Icon(
                      Icons.share_outlined,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    onPressed: () => onShare(obs),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/

/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app_tesis/screens/login_screen/auth_service.dart';

class MyObservationsScreen extends StatefulWidget {
  const MyObservationsScreen({super.key});

  @override
  State<MyObservationsScreen> createState() => _MyObservationsScreenState();
}

class _MyObservationsScreenState extends State<MyObservationsScreen> {
  static const _baseUrl = 'http://10.0.2.2:8080';

  List<dynamic> _observations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadObservations();
  }

Future<void> _loadObservations() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final token = await AuthService.getToken();
    debugPrint('>>> Token usado: $token');

    final response = await http.get(
      Uri.parse('$_baseUrl/api/reportes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    debugPrint('>>> Status: ${response.statusCode}');
    debugPrint('>>> Body: ${response.body}');

    if (!mounted) return;

    if (response.statusCode == 200) {
      setState(() {
        _observations = jsonDecode(response.body);
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Error ${response.statusCode} al cargar observaciones';
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _errorMessage = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }
}
 
  /*Future<void> _loadObservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/reportes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _observations = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error al cargar observaciones';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }*/

  

  Future<void> _deleteObservation(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red.shade600, size: 56),
            const SizedBox(height: 12),
            const Text(
              '¿Quieres eliminar esta observación?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/reportes/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observación eliminada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadObservations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar'),
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

  Color _priorityColor(String? prioridad) {
    switch (prioridad?.toLowerCase()) {
      case 'alta':
        return Colors.red.shade600;
      case 'media':
        return Colors.orange.shade600;
      case 'baja':
        return Colors.green.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  IconData _categoryIcon(String? categoria) {
    switch (categoria?.toLowerCase()) {
      case 'fauna':
        return Icons.pets;
      case 'flora':
        return Icons.eco;
      case 'agua':
        return Icons.water_drop;
      case 'aire':
        return Icons.air;
      case 'suelo':
        return Icons.landscape;
      default:
        return Icons.nature;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Mis Observaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadObservations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadObservations,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : _observations.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aún no tienes observaciones',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadObservations,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _observations.length,
                itemBuilder: (ctx, i) {
                  final obs = _observations[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Ícono categoría ──────────
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.green.shade50,
                            child: Icon(
                              _categoryIcon(obs['categoriaNombre']),
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // ── Info ─────────────────────
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  obs['titulo'] ?? 'Sin título',
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
                                      obs['categoriaNombre'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _priorityColor(
                                          obs['prioridadNombre'],
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        obs['prioridadNombre'] ?? '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _priorityColor(
                                            obs['prioridadNombre'],
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (obs['descripcion'] != null &&
                                    obs['descripcion'].toString().isNotEmpty)
                                  Text(
                                    obs['descripcion'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 12,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${obs['latitud']?.toStringAsFixed(3)}, '
                                      '${obs['longitud']?.toStringAsFixed(3)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ── Menú opciones ────────────
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey.shade500,
                            ),
                            onSelected: (value) {
                              if (value == 'borrar') {
                                _deleteObservation(obs['id'] as int);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'borrar',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
}*/

/*import 'package:flutter/material.dart';

class MyObservationsScreen extends StatelessWidget {
  const MyObservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Observaciones")),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Observación 1"),
            subtitle: const Text("Fauna"),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'editar') {
                  // editar
                } else if (value == 'borrar') {
                  // borrar
                } else if (value == 'compartir') {
                  // compartir
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'editar', child: Text("Editar")),
                const PopupMenuItem(
                    value: 'borrar', child: Text("Borrar")),
                const PopupMenuItem(
                    value: 'compartir', child: Text("Compartir")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}*/
