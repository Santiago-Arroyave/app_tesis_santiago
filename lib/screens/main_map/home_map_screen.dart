import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/main_map/map_filter_sheet.dart';
import 'package:goblink_park/screens/reports/report_detail_screen.dart';
import 'package:goblink_park/widgets/notification_bell_button.dart';

enum MapLayerType { satellite, topographic, standard }

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen>
    with TickerProviderStateMixin {
  static const _baseUrl = ApiConfig.baseUrl;
  static const _defaultCenter = LatLng(4.1151, -76.1976); // PNR Páramo del Duende

  List<dynamic> _reportes = [];
  List<dynamic> _categorias = [];
  bool _isSyncing = false;
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionSubscription;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  MapLayerType _currentMapLayer = MapLayerType.satellite;
  String _searchQuery = '';
  MapFilterOptions _filters = const MapFilterOptions();

  // Reporte seleccionado actualmente en el mapa
  Map<String, dynamic>? _selectedReporte;

  @override
  void initState() {
    super.initState();
    // Iniciar las consultas de datos en paralelo sin bloquear el renderizado del mapa
    Future.microtask(() {
      _loadReportes();
      _loadCategorias();
    });
    _getCurrentLocation();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReportes() async {
    debugPrint('>>> GET Reportes en Mapa solicitado');
    if (mounted) setState(() => _isSyncing = true);
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/reportes'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 7));
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
          _isSyncing = false;
        });
      } else {
        setState(() => _isSyncing = false);
      }
    } catch (e) {
      debugPrint('Error al cargar reportes en mapa: $e');
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _loadCategorias() async {
    debugPrint('>>> GET Categorias en Mapa solicitado');
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/categorias'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 7));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          setState(() {
            _categorias = body
                .where((c) => c['estado'] == null || c['estado'] == true)
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar categorías en mapa: $e');
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

      // 1. Obtener última posición conocida de forma instantánea si existe
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          final loc = LatLng(lastKnown.latitude, lastKnown.longitude);
          setState(() => _currentLocation = loc);
        }
      } catch (_) {}

      // 2. Obtener posición GPS actual con límite de tiempo para no congelar la pantalla
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );

      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = location;
      });

      _animatedMapMove(location, 15.5);
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
      },
    );
  }

  // Animación de cámara suave para desplazar y centrar el mapa
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;

    final latTween = Tween<double>(
      begin: currentCenter.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: currentCenter.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: currentZoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  // Enfoque y animación de cámara hacia los reportes de una categoría
  void _focusOnCategoryReports(String? category) {
    List<dynamic> targetList;
    if (category == null || category == 'Todos') {
      targetList = _reportes;
    } else {
      targetList = _reportes.where((r) => _matchesCategory(r, category)).toList();
    }

    if (targetList.isNotEmpty) {
      double sumLat = 0;
      double sumLng = 0;
      int count = 0;

      for (final r in targetList) {
        final lat = (r['latitud'] as num?)?.toDouble();
        final lng = (r['longitud'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          sumLat += lat;
          sumLng += lng;
          count++;
        }
      }

      if (count > 0) {
        final targetCenter = LatLng(sumLat / count, sumLng / count);
        _animatedMapMove(targetCenter, category == null ? 14.0 : 15.2);
      }
    }
  }

  String _getTileUrl() {
    switch (_currentMapLayer) {
      case MapLayerType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.topographic:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  bool _matchesCategory(dynamic r, String catKey) {
    final cat = (r['categoriaNombre'] ?? r['categoria']?['nombre'] ?? '')
        .toString()
        .toLowerCase();
    switch (catKey.toLowerCase()) {
      case 'flora':
        return cat.contains('flora') ||
            cat.contains('vegetal') ||
            cat.contains('árbol') ||
            cat.contains('bosque');
      case 'fauna':
        return cat.contains('fauna') ||
            cat.contains('animal') ||
            cat.contains('avistamiento') ||
            cat.contains('pájaro') ||
            cat.contains('ave');
      case 'suelo':
        return cat.contains('suelo') || cat.contains('tierra');
      case 'agua':
        return cat.contains('agua') ||
            cat.contains('hídric') ||
            cat.contains('río') ||
            cat.contains('quebrada') ||
            cat.contains('laguna');
      case 'aire':
        return cat.contains('aire') ||
            cat.contains('clima') ||
            cat.contains('viento') ||
            cat.contains('atmósfer');
      default:
        return cat.contains(catKey.toLowerCase());
    }
  }

  int get _countTodos => _reportes.length;
  int get _countFlora => _reportes.where((r) => _matchesCategory(r, 'flora')).length;
  int get _countFauna => _reportes.where((r) => _matchesCategory(r, 'fauna')).length;
  int get _countSuelo => _reportes.where((r) => _matchesCategory(r, 'suelo')).length;
  int get _countAgua => _reportes.where((r) => _matchesCategory(r, 'agua')).length;
  int get _countAire => _reportes.where((r) => _matchesCategory(r, 'aire')).length;

  List<dynamic> get _filteredReportes {
    return _reportes.where((r) {
      if (r['latitud'] == null || r['longitud'] == null) return false;

      // 1. Filtro de Categoría
      if (_filters.category != null && _filters.category != 'Todas') {
        if (!_matchesCategory(r, _filters.category!)) return false;
      }

      // 2. Filtro de Estado
      if (_filters.status != null && _filters.status != 'Todos') {
        final est = (r['estadoReporteNombre'] ?? r['estado']?['nombre'] ?? '')
            .toString()
            .toLowerCase();
        if (!est.contains(_filters.status!.toLowerCase())) return false;
      }

      // 3. Filtro de Prioridad
      if (_filters.priority != null && _filters.priority != 'Todas') {
        final prio = (r['prioridadNombre'] ?? r['prioridad']?['nombre'] ?? '')
            .toString()
            .toLowerCase();
        if (!prio.contains(_filters.priority!.toLowerCase())) return false;
      }

      // 4. Filtro de Rango de Fechas
      if (_filters.dateRange != null) {
        final rawDate = r['fechaReporte'] ?? r['fechaCreacion'];
        if (rawDate != null) {
          try {
            final dt = DateTime.parse(rawDate.toString());
            final start = _filters.dateRange!.start;
            final end = _filters.dateRange!.end.add(const Duration(days: 1));
            if (dt.isBefore(start) || dt.isAfter(end)) return false;
          } catch (_) {}
        }
      }

      // 5. Filtro de Texto de Búsqueda
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final titulo = (r['titulo'] ?? '').toString().toLowerCase();
        final desc = (r['descripcion'] ?? '').toString().toLowerCase();
        final cat = (r['categoriaNombre'] ?? '').toString().toLowerCase();
        final sector = (r['sector'] ?? r['ubicacionTexto'] ?? '').toString().toLowerCase();
        if (!titulo.contains(q) &&
            !desc.contains(q) &&
            !cat.contains(q) &&
            !sector.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  IconData _getCategoryIcon(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (c.contains('fauna') || c.contains('animal') || c.contains('avistamiento')) {
      return Icons.pets;
    }
    if (c.contains('flora') || c.contains('vegetal') || c.contains('árbol') || c.contains('bosque')) {
      return Icons.eco;
    }
    if (c.contains('suelo') || c.contains('tierra')) {
      return Icons.landscape;
    }
    if (c.contains('agua') || c.contains('hídric') || c.contains('río')) {
      return Icons.water_drop;
    }
    if (c.contains('aire') || c.contains('clima') || c.contains('viento')) {
      return Icons.air;
    }
    return Icons.eco;
  }

  Color _getCategoryPinColor(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (c.contains('fauna') || c.contains('animal') || c.contains('avistamiento')) {
      return const Color(0xFF9A6735); // Ocre / Marrón fauna
    }
    if (c.contains('flora') || c.contains('vegetal') || c.contains('árbol')) {
      return const Color(0xFF1E5E3A); // Verde institucional flora
    }
    if (c.contains('suelo') || c.contains('tierra')) {
      return const Color(0xFF8C5E48); // Café arcilla suelo
    }
    if (c.contains('agua') || c.contains('hídric')) {
      return const Color(0xFF2563EB); // Azul hídrico agua
    }
    if (c.contains('aire') || c.contains('clima')) {
      return const Color(0xFF0284C7); // Celeste / Cian aire
    }
    return const Color(0xFF1E5E3A);
  }

  Color _getStatusColor(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s.contains('valid') || s.contains('aprob')) return const Color(0xFF15803D);
    if (s.contains('revis')) return const Color(0xFFB45309);
    if (s.contains('seguim')) return const Color(0xFF0284C7);
    return const Color(0xFF6B7280);
  }

  Color _getStatusBgColor(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s.contains('valid') || s.contains('aprob')) return const Color(0xFFDCFCE7);
    if (s.contains('revis')) return const Color(0xFFFEF3C7);
    if (s.contains('seguim')) return const Color(0xFFE0F2FE);
    return const Color(0xFFF3F4F6);
  }

  Color _getPriorityColor(String? prioridad) {
    final p = prioridad?.toLowerCase() ?? '';
    if (p.contains('alta')) return const Color(0xFFEF4444);
    if (p.contains('med')) return const Color(0xFFF59E0B);
    if (p.contains('baj')) return const Color(0xFF10B981);
    return const Color(0xFF6B7280);
  }

  Color _getPriorityBgColor(String? prioridad) {
    final p = prioridad?.toLowerCase() ?? '';
    if (p.contains('alta')) return const Color(0xFFFEF2F2);
    if (p.contains('med')) return const Color(0xFFFFFBEB);
    if (p.contains('baj')) return const Color(0xFFF0FDF4);
    return const Color(0xFFF3F4F6);
  }

  String _categoryAsset(String? categoria) {
    const map = {
      'Fauna': 'assets/images/Oso de anteojos-2.jpeg',
      'Flora': 'assets/images/Flora.jpeg',
      'Agua': 'assets/images/Agua.jpeg',
      'Aire': 'assets/images/Aire.jpeg',
      'Suelo': 'assets/images/Suelo.jpeg',
    };
    return map[categoria] ?? 'assets/images/Flora.jpeg';
  }

  String? _getObservationImageUrl(Map<String, dynamic> reporte) {
    try {
      final fotoPrincipal = reporte['fotoPrincipalUrl'] ?? reporte['fotoUrl'] ?? reporte['urlFoto'] ?? reporte['foto'];
      if (fotoPrincipal != null && fotoPrincipal.toString().trim().isNotEmpty) {
        final str = fotoPrincipal.toString().trim();
        if (str.startsWith('http://') || str.startsWith('https://')) {
          return str;
        }
      }
      final evidencias = reporte['evidencias'];
      if (evidencias is List && evidencias.isNotEmpty) {
        for (final evidencia in evidencias) {
          if (evidencia is Map) {
            final evUrl = evidencia['archivoUrl'] ?? evidencia['url'] ?? evidencia['urlArchivo'];
            if (evUrl != null && evUrl.toString().trim().isNotEmpty) {
              final str = evUrl.toString().trim();
              if (str.startsWith('http://') || str.startsWith('https://')) {
                return str;
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Uint8List? _getObservationImage(Map<String, dynamic> reporte) {
    try {
      String? base64Image;
      final fotoPrincipal = reporte['fotoPrincipalUrl'] ?? reporte['fotoUrl'];
      if (fotoPrincipal != null && fotoPrincipal.toString().trim().isNotEmpty) {
        base64Image = fotoPrincipal.toString().trim();
      }

      if (base64Image == null) {
        final evidencias = reporte['evidencias'];
        if (evidencias is List && evidencias.isNotEmpty) {
          for (final evidencia in evidencias) {
            if (evidencia is Map &&
                evidencia['archivoBase64'] != null &&
                evidencia['archivoBase64'].toString().trim().isNotEmpty) {
              base64Image = evidencia['archivoBase64'].toString().trim();
              break;
            }
          }
        }
      }

      if (base64Image == null || base64Image.isEmpty) return null;
      if (base64Image.contains(',')) {
        base64Image = base64Image.split(',').last;
      }
      return base64Decode(base64Image);
    } catch (e) {
      debugPrint('Error al decodificar imagen del reporte: $e');
      return null;
    }
  }

  String _formatReportDate(dynamic dateVal) {
    if (dateVal == null) return 'Reciente';
    final str = dateVal.toString();
    try {
      final dt = DateTime.parse(str);
      const months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $hour:$minute';
    } catch (_) {
      if (str.length >= 10) return str.substring(0, 10);
      return str;
    }
  }

  void _onMarkerTapped(Map<String, dynamic> reporte) {
    final lat = (reporte['latitud'] as num).toDouble();
    final lng = (reporte['longitud'] as num).toDouble();
    final point = LatLng(lat, lng);

    setState(() {
      _selectedReporte = reporte;
    });

    _animatedMapMove(point, 16.5);
  }

  Future<void> _navigateToReportDetail(Map<String, dynamic> reporte) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(reporte: reporte),
      ),
    );

    if (result is Map && result['action'] == 'center_on_map') {
      final targetReporte = result['reporte'] as Map<String, dynamic>? ?? reporte;
      _onMarkerTapped(targetReporte);
    }
  }

  void _onQuickChipTapped(String? catName) {
    setState(() {
      if (catName == null || catName == 'Todos') {
        _filters = _filters.copyWith(category: () => null);
      } else {
        final current = _filters.category;
        _filters = _filters.copyWith(
          category: () => current == catName ? null : catName,
        );
      }
      _selectedReporte = null;
    });

    _focusOnCategoryReports(_filters.category);
  }

  void _showLayersModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Capa del Mapa",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildLayerItem(
                title: "Satelital (Alta Resolución)",
                subtitle: "Esri World Imagery – Vegetación y relieve real",
                icon: Icons.satellite_alt_rounded,
                isSelected: _currentMapLayer == MapLayerType.satellite,
                onTap: () {
                  setState(() => _currentMapLayer = MapLayerType.satellite);
                  Navigator.pop(ctx);
                },
              ),
              _buildLayerItem(
                title: "Relieve / Topográfico",
                subtitle: "Esri World Topo – Curvas de nivel del páramo",
                icon: Icons.terrain_rounded,
                isSelected: _currentMapLayer == MapLayerType.topographic,
                onTap: () {
                  setState(() => _currentMapLayer = MapLayerType.topographic);
                  Navigator.pop(ctx);
                },
              ),
              _buildLayerItem(
                title: "Estándar / Calles",
                subtitle: "OpenStreetMap – Senderos y caminos principales",
                icon: Icons.map_rounded,
                isSelected: _currentMapLayer == MapLayerType.standard,
                onTap: () {
                  setState(() => _currentMapLayer = MapLayerType.standard);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayerItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isSelected
        ? (isDark ? const Color(0xFF1B2620) : const Color(0xFFE8F5E9))
        : (isDark ? const Color(0xFF222E27) : const Color(0xFFF9FAFB));
    final borderColor = isSelected
        ? (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A))
        : (isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB));
    final iconColor = isSelected
        ? (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A))
        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle_rounded,
                color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                size: 22,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  void _showFullFilterModal() {
    MapFilterSheet.show(
      context: context,
      currentFilters: _filters,
      onApply: (newFilters) {
        setState(() {
          _filters = newFilters;
          _selectedReporte = null;
        });
        _focusOnCategoryReports(_filters.category);
      },
    );
  }

  // ===========================================================================
  // CABECERA PRINCIPAL: GOBLIN PARK, RECARGA EN TIEMPO REAL Y NOTIFICACIONES
  // ===========================================================================

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x40000000) : const Color(0x1F000000),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón de recarga en tiempo real
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? const Color(0xFF52B788) : const Color(0xFF0F3A22),
              size: 26,
            ),
            tooltip: 'Actualizar reportes en tiempo real',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Actualizando reportes en tiempo real...'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _loadReportes();
            },
          ),
          const SizedBox(width: 2),
          ClipOval(
            child: Image.asset(
              'assets/images/Logo verde.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Goblin Park",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF0F3A22),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  "PNR Páramo del Duende",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFA3B899) : const Color(0xFF2E4F3E),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBellButton(size: 26),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x40000000) : const Color(0x14000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: "Buscar reportes, lugares o coordenadas...",
          hintStyle: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF9CA3AF),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            size: 22,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: _filters.hasActiveFilters
                      ? (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A))
                      : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                  size: 20,
                ),
                onPressed: _showFullFilterModal,
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildQuickCategoryChips() {
    final selCat = _filters.category;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> categoryChipWidgets = [];

    // 1. Chip Todos
    categoryChipWidgets.add(
      _buildQuickChip(
        label: "Todos",
        count: _countTodos,
        icon: null,
        isSelected: selCat == null || selCat == 'Todas',
        activeColor: const Color(0xFF1E5E3A),
        onTap: () => _onQuickChipTapped(null),
      ),
    );
    categoryChipWidgets.add(const SizedBox(width: 8));

    // 2. Chips de Categorías dinámicas o por defecto
    if (_categorias.isNotEmpty) {
      for (final cat in _categorias) {
        final nom = (cat['nombre'] ?? '').toString();
        if (nom.trim().isEmpty) continue;
        final count = _reportes.where((r) => _matchesCategory(r, nom)).length;
        categoryChipWidgets.add(
          _buildQuickChip(
            label: nom,
            count: count,
            icon: _getCategoryIcon(nom),
            isSelected: selCat == nom,
            activeColor: _getCategoryPinColor(nom),
            onTap: () => _onQuickChipTapped(nom),
          ),
        );
        categoryChipWidgets.add(const SizedBox(width: 8));
      }
    } else {
      final defaultList = [
        ('Flora', _countFlora, Icons.eco, const Color(0xFF1E5E3A)),
        ('Fauna', _countFauna, Icons.pets, const Color(0xFF9A6735)),
        ('Suelo', _countSuelo, Icons.landscape, const Color(0xFF8C5E48)),
        ('Agua', _countAgua, Icons.water_drop, const Color(0xFF2563EB)),
        ('Aire', _countAire, Icons.air, const Color(0xFF0284C7)),
      ];
      for (final item in defaultList) {
        categoryChipWidgets.add(
          _buildQuickChip(
            label: item.$1,
            count: item.$2,
            icon: item.$3,
            isSelected: selCat == item.$1,
            activeColor: item.$4,
            onTap: () => _onQuickChipTapped(item.$1),
          ),
        );
        categoryChipWidgets.add(const SizedBox(width: 8));
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            ...categoryChipWidgets,

            // 7. Botón desplegable / ajustes de filtros completos
            InkWell(
              onTap: _showFullFilterModal,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _filters.hasActiveFilters
                        ? (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A))
                        : (isDark ? const Color(0x26FFFFFF) : const Color(0xFFE5E7EB)),
                    width: _filters.hasActiveFilters ? 1.5 : 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 15,
                      color: _filters.hasActiveFilters
                          ? (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A))
                          : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563)),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required int count,
    required IconData? icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? const Color(0x26FFFFFF) : const Color(0xFFE5E7EB)),
              width: 1.1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : activeColor,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFE8F5E9) : const Color(0xFF374151)),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(50)
                      : (isDark ? const Color(0xFF222E27) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTONES FLOTANTES DE CONTROL (LADO DERECHO)
  // ===========================================================================

  Widget _buildFloatingControlButton({
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.colorScheme.surface,
      shape: CircleBorder(
        side: isDark ? const BorderSide(color: Color(0x26FFFFFF), width: 1) : BorderSide.none,
      ),
      elevation: 3,
      shadowColor: const Color(0x26000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TARJETA DE UBICACIÓN ACTUAL FLOTANTE
  // ===========================================================================

  Widget _buildLocationCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final latStr = _currentLocation != null
        ? '${_currentLocation!.latitude.toStringAsFixed(4)}° N, ${_currentLocation!.longitude.toStringAsFixed(4)}° W'
        : '4.1151° N, 76.1976° W';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x40000000) : const Color(0x1A000000),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (_currentLocation != null) {
            _animatedMapMove(_currentLocation!, 16);
          } else {
            _getCurrentLocation();
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.radio_button_checked,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Tu ubicación actual",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "PNR Páramo del Duende · $latStr",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TARJETA FLOTANTE DE VISTA PREVIA (PRE-DETALLE AL SELECCIONAR UN PIN)
  // ===========================================================================

  Widget _buildSelectedReportCard(Map<String, dynamic> r) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final catNombre = r['categoriaNombre'] ?? r['categoria']?['nombre'] ?? 'Flora';
    final estadoNombre = r['estadoReporteNombre'] ?? r['estado']?['nombre'] ?? 'Validado';
    final prioridadNombre = r['prioridadNombre'] ?? r['prioridad']?['nombre'] ?? 'Media';
    final titulo = r['titulo']?.toString().isNotEmpty == true
        ? r['titulo'].toString()
        : 'Observación en el Páramo';
    final sector = r['sector'] ?? r['ubicacionTexto'] ?? 'Sector Laguna Verde';
    final fecha = _formatReportDate(r['fechaReporte'] ?? r['fechaCreacion']);

    final String? imgUrl = _getObservationImageUrl(r);
    final Uint8List? imgBytes = imgUrl == null ? _getObservationImage(r) : null;
    final catColor = _getCategoryPinColor(catNombre);
    final statusColor = _getStatusColor(estadoNombre);
    final statusBgColor = isDark ? statusColor.withAlpha(40) : _getStatusBgColor(estadoNombre);
    final prioColor = _getPriorityColor(prioridadNombre);
    final prioBgColor = isDark ? prioColor.withAlpha(40) : _getPriorityBgColor(prioridadNombre);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x50000000) : const Color(0x22000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _navigateToReportDetail(r),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Izquierda: Imagen destacada cuadrada medianita 78x78
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 78,
                    height: 78,
                    child: imgUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            placeholder: (context, url) => Container(
                              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              _categoryAsset(catNombre),
                              fit: BoxFit.cover,
                            ),
                          )
                        : (imgBytes != null
                            ? Image.memory(
                                imgBytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            : Image.asset(
                                _categoryAsset(catNombre),
                                fit: BoxFit.cover,
                              )),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Centro (Expanded): Chips, Título, Fecha y Ubicación
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fila superior de chips: Categoría, Estado y Prioridad
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Chip de Categoría
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: catColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: catColor.withAlpha(90), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getCategoryIcon(catNombre), size: 10.5, color: catColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    catNombre,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: catColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),

                            // Chip de Estado
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withAlpha(90), width: 0.8),
                              ),
                              child: Text(
                                estadoNombre,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),

                            // Chip de Prioridad con indicador de color
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: prioBgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: prioColor.withAlpha(90), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: prioColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    prioridadNombre,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: prioColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Título del reporte en negrita
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Fecha y hora con icono de calendario pequeño
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            fecha,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Ubicación con icono de pin pequeño
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 13,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sector,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Derecha: Botón superior (X) y Flechita hacia el detalle
                SizedBox(
                  height: 78,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Botón superior para cerrar (X) para deseleccionar el pin
                      InkWell(
                        onTap: () => setState(() => _selectedReporte = null),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                      // Flecha hacia la derecha como indicador visual de navegación
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 24,
                        color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF374151),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MARCADOR DE USUARIO Y PINES TEMÁTICOS PERSONALIZADOS
  // ===========================================================================

  Marker _buildUserLocationMarker() {
    return Marker(
      point: _currentLocation!,
      width: 60,
      height: 60,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x332563EB),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x4D2563EB),
                border: Border.all(color: const Color(0x662563EB), width: 1.5),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerPin({
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (isSelected)
            Positioned(
              top: -6,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(50),
                  border: Border.all(color: color.withAlpha(160), width: 2),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isSelected ? 40 : 36,
                height: isSelected ? 40 : 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 2.8 : 2.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isSelected ? 21 : 19,
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -3),
                child: CustomPaint(
                  size: Size(isSelected ? 12 : 10, isSelected ? 7 : 6),
                  painter: _PinTrianglePainter(color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Capa de Mapa Satelital / Relieve
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? _defaultCenter,
              initialZoom: 14,
              onTap: (_, _) {
                if (_selectedReporte != null) {
                  setState(() => _selectedReporte = null);
                }
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(_currentMapLayer),
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.example.app_tesis',
                maxZoom: 19,
                maxNativeZoom: _currentMapLayer == MapLayerType.standard ? 19 : 18,
                keepBuffer: 3,
                panBuffer: 1,
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 150)),
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              ),
              MarkerLayer(
                markers: [
                  ..._filteredReportes.map((r) {
                    final cat = (r['categoriaNombre'] ?? '').toString();
                    final icon = _getCategoryIcon(cat);
                    final pinColor = _getCategoryPinColor(cat);
                    final isSelected = _selectedReporte != null &&
                        ((_selectedReporte!['id'] != null && _selectedReporte!['id'] == r['id']) ||
                            (_selectedReporte == r));

                    return Marker(
                      point: LatLng(
                        (r['latitud'] as num).toDouble(),
                        (r['longitud'] as num).toDouble(),
                      ),
                      width: 56,
                      height: 60,
                      child: _buildMarkerPin(
                        color: pinColor,
                        icon: icon,
                        isSelected: isSelected,
                        onTap: () => _onMarkerTapped(Map<String, dynamic>.from(r)),
                      ),
                    );
                  }),
                  if (_currentLocation != null) _buildUserLocationMarker(),
                ],
              ),
            ],
          ),

          // 2. Indicador sutil no bloqueante de sincronización de observaciones
          if (_isSyncing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 162,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E2822) : Colors.white).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0x3352B788) : const Color(0x331E5E3A),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sincronizando observaciones...',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF1E5E3A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Header flotante + Barra de búsqueda + Chips de Categorías rápidas
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 4),
                  _buildSearchBar(),
                  _buildQuickCategoryChips(),
                ],
              ),
            ),
          ),

          // 4. Botones flotantes de control (lado derecho)
          Positioned(
            right: 16,
            bottom: _selectedReporte != null ? 140 : 85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingControlButton(
                  icon: Icons.my_location,
                  iconColor: const Color(0xFF2563EB),
                  tooltip: "Mi ubicación",
                  onTap: () {
                    if (_currentLocation != null) {
                      _animatedMapMove(_currentLocation!, 16);
                    } else {
                      _getCurrentLocation();
                    }
                  },
                ),
                const SizedBox(height: 10),
                _buildFloatingControlButton(
                  icon: Icons.layers_outlined,
                  iconColor: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                  tooltip: "Capas de mapa",
                  onTap: _showLayersModal,
                ),
                const SizedBox(height: 10),
                _buildFloatingControlButton(
                  icon: Icons.near_me_outlined,
                  iconColor: isDark ? const Color(0xFF52B788) : const Color(0xFF0F3A22),
                  tooltip: "Orientación norte",
                  onTap: () => _mapController.rotate(0),
                ),
              ],
            ),
          ),

          // 5. Tarjeta informativa de "Tu ubicación actual" O Tarjeta de Preview de Reporte (al seleccionar un pin)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _selectedReporte != null
                  ? _buildSelectedReportCard(_selectedReporte!)
                  : _buildLocationCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTrianglePainter extends CustomPainter {
  final Color color;
  const _PinTrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
