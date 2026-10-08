import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:goblink_park/screens/api_connection/api_config.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  static const _baseUrl =
      '${ApiConfig.baseUrl}'; // URL de producción
  //static const _initialCenter = LatLng(4.0847, -76.1954);
  // Ubicación inicial de respaldo
  static const _defaultCenter = LatLng(4.0847, -76.1954);

  List<dynamic> _reportes = [];
  bool _isLoading = true;

  LatLng? _currentLocation;

  StreamSubscription<Position>? _positionSubscription;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();

    _loadReportes();
    _getCurrentLocation();
    _startLocationTracking();
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

        debugPrint('========================================');
        debugPrint('RESPUESTA API REPORTES:');
        debugPrint(const JsonEncoder.withIndent('  ').convert(body));
        debugPrint('========================================');

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

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint('El servicio de ubicación está desactivado');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Permiso de ubicación no concedido');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = location;
      });

      // Centrar el mapa en la ubicación real
      _mapController.move(location, 15);

      debugPrint(
        'Ubicación actual: '
        '${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');
    }
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (!mounted) return;

            final location = LatLng(position.latitude, position.longitude);

            setState(() {
              _currentLocation = location;
            });

            _mapController.move(location, 15);
          },
        );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Color _priorityColor(String? prioridad) {
    switch (prioridad?.toLowerCase()) {
      case 'alta':
        return Colors.red;
      case 'media':
        return Colors.orange;
      case 'baja':
        return Color.fromARGB(255, 7, 83, 11);
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

  Uint8List? _getObservationImage(Map<String, dynamic> reporte) {
    try {
      String? base64Image;

      // 1. Primero intentamos tomar la imagen principal
      final fotoPrincipal = reporte['fotoPrincipalUrl'];

      if (fotoPrincipal != null && fotoPrincipal.toString().trim().isNotEmpty) {
        base64Image = fotoPrincipal.toString().trim();
      }

      // 2. Si no existe, buscamos en evidencias
      if (base64Image == null) {
        final evidencias = reporte['evidencias'];

        if (evidencias is List && evidencias.isNotEmpty) {
          for (final evidencia in evidencias) {
            if (evidencia is Map &&
                evidencia['tipoArchivo']?.toString().toLowerCase() ==
                    'imagen' &&
                evidencia['archivoBase64'] != null &&
                evidencia['archivoBase64'].toString().trim().isNotEmpty) {
              base64Image = evidencia['archivoBase64'].toString().trim();
              break;
            }
          }
        }
      }

      if (base64Image == null || base64Image.isEmpty) {
        return null;
      }

      // Por si algún día el backend envía:
      // data:image/jpeg;base64,...
      if (base64Image.contains(',')) {
        base64Image = base64Image.split(',').last;
      }

      return base64Decode(base64Image);
    } catch (e) {
      debugPrint('Error al decodificar imagen del reporte: $e');
      return null;
    }
  }

  String? _observationImage(Map<String, dynamic> reporte) {
    // Posibles nombres de campo para una imagen individual
    final possibleFields = [
      'imagenUrl',
      'imagen',
      'fotoUrl',
      'foto',
      'imagenReporte',
      'evidenciaUrl',
    ];

    for (final field in possibleFields) {
      final value = reporte[field];

      if (value != null && value.toString().trim().isNotEmpty) {
        return _resolveImageUrl(value.toString());
      }
    }

    // Si el backend devuelve una lista de evidencias/imágenes
    final possibleLists = [
      'imagenes',
      'evidencias',
      'evidenciasReporte',
      'fotos',
    ];

    for (final field in possibleLists) {
      final value = reporte[field];

      if (value is List && value.isNotEmpty) {
        final first = value.first;

        if (first is String && first.trim().isNotEmpty) {
          return _resolveImageUrl(first);
        }

        if (first is Map<String, dynamic>) {
          final imageValue =
              first['url'] ??
              first['imagenUrl'] ??
              first['imagen'] ??
              first['ruta'] ??
              first['path'];

          if (imageValue != null && imageValue.toString().trim().isNotEmpty) {
            return _resolveImageUrl(imageValue.toString());
          }
        }
      }
    }

    return null;
  }

  String _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    if (url.startsWith('/')) {
      return '$_baseUrl$url';
    }

    return '$_baseUrl/$url';
  }

  void _showObservationDetail(Map<String, dynamic> reporte) {
    final Uint8List? observationImage = _getObservationImage(reporte);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        padding: const EdgeInsets.all(10),
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
        child: SizedBox(
          height: 104,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =====================================================
              // IMAGEN PRINCIPAL DE LA OBSERVACIÓN
              // =====================================================
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: observationImage != null
                      ? Image.memory(
                          observationImage,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey.shade500,
                            size: 30,
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // =====================================================
              // INFORMACIÓN
              // =====================================================
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        reporte['titulo']?.toString().isNotEmpty == true
                            ? reporte['titulo'].toString()
                            : 'Observación',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          Text(
                            'Prioridad ${reporte['prioridadNombre'] ?? ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _priorityColor(reporte['prioridadNombre']),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Estado: ${reporte['estadoReporteNombre'] ?? 'Pendiente'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Fecha: ${reporte['fechaReporte'] != null ? reporte['fechaReporte'].toString().substring(0, 10) : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // =====================================================
              // CATEGORÍA - PEQUEÑA Y ARRIBA A LA DERECHA
              // =====================================================
              Padding(
                padding: const EdgeInsets.only(top: 0, right: 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    _categoryImage(reporte['categoriaNombre']?.toString()),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*void _showObservationDetail(Map<String, dynamic> reporte) {
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
  }*/

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation ?? _defaultCenter,
            initialZoom: 14,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app_tesis',
            ),
            MarkerLayer(
              markers: [
                // =========================================================
                // MARCADORES DE LOS REPORTES
                // =========================================================
                ..._reportes.map((r) {
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
                }),

                // =========================================================
                // MARCADOR DE LA UBICACIÓN ACTUAL DEL USUARIO
                // =========================================================
                if (_currentLocation != null)
                  Marker(
                    point: _currentLocation!,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withValues(alpha: 0.20),
                      ),
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            /*MarkerLayer(
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
            ),*/
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón para ir a mi ubicación
              FloatingActionButton.small(
                heroTag: 'locationButton',
                onPressed: () {
                  if (_currentLocation != null) {
                    _mapController.move(_currentLocation!, 17);
                  } else {
                    _getCurrentLocation();
                  }
                },
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.blue),
              ),

              const SizedBox(height: 10),

              // Botón actualizar reportes
              FloatingActionButton.small(
                heroTag: 'refreshButton',
                onPressed: _loadReportes,
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.refresh,
                  color: Color.fromARGB(255, 7, 83, 11),
                ),
              ),
            ],
          ),
        ),

        /*Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: _loadReportes,
            backgroundColor: Colors.white,
            child: Icon(Icons.refresh, color: Color.fromARGB(255, 7, 83, 11)),
          ),
        ),*/
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

