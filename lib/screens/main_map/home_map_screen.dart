import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:app_tesis/screens/login_screen/auth_service.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  static const _baseUrl = 'http://10.0.2.2:8080';
  static const _initialCenter = LatLng(4.0847, -76.1954);

  List<dynamic> _reportes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportes();
  }

  Future<void> _loadReportes() async {
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
        final body = jsonDecode(response.body);
        List<dynamic> data;
        if (body is List) {
          data = body;
        } else if (body is Map && body.containsKey('content')) {
          data = body['content'] as List;
        } else {
          data = [];
        }
        setState(() {
          _reportes = data
              .where((r) => r['latitud'] != null && r['longitud'] != null)
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _priorityColor(String? prioridad) {
    switch (prioridad?.toLowerCase()) {
      case 'alta':
        return Colors.red;
      case 'media':
        return Colors.orange;
      case 'baja':
        return Colors.green;
      default:
        return Colors.blue;
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

  void _showObservationDetail(Map<String, dynamic> reporte) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen de la observación
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  _categoryImage(reporte['categoriaNombre']),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reporte['categoriaNombre'] ?? 'Sin categoría',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Prioridad ${reporte['prioridadNombre'] ?? ''} ',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: _priorityColor(reporte['prioridadNombre']),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estado: ${reporte['estadoReporteNombre'] ?? 'Pendiente'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: ${reporte['fechaEvento']?.toString().substring(0, 10) ?? ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Foto perfil usuario (avatar)
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.green.shade100,
                child: Text(
                  (reporte['usuarioNombre'] ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: _initialCenter, initialZoom: 14),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app_tesis',
            ),
            MarkerLayer(
              markers: _reportes.map((r) {
                final color = _priorityColor(r['prioridadNombre']);
                return Marker(
                  point: LatLng(
                    (r['latitud'] as num).toDouble(),
                    (r['longitud'] as num).toDouble(),
                  ),
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    onTap: () =>
                        _showObservationDetail(Map<String, dynamic>.from(r)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Indicador de carga
        if (_isLoading)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cargando observaciones...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Botón refresh
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: _loadReportes,
            backgroundColor: Colors.white,
            child: Icon(Icons.refresh, color: Colors.green.shade700),
          ),
        ),
      ],
    );
  }
}


/*import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HomeMapScreen extends StatelessWidget {
  const HomeMapScreen({super.key});

   @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(4.0847, -76.1954),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'com.example.app_tesis',
        ),
        // 📍 Marcador ejemplo
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(4.0847, -76.1954),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = LatLng(4.0847, -76.1954); // Tuluá

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio', style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.green,
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 14),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.app_tesis',
          ),

          // 📍 Marcador ejemplo
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }*/

