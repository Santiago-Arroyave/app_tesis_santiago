import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'observation_category_screen.dart';

class ObservationMapScreen extends StatefulWidget {
  const ObservationMapScreen({super.key});

  @override
  State<ObservationMapScreen> createState() =>
      _ObservationMapScreenState();
}

class _ObservationMapScreenState extends State<ObservationMapScreen> {
  // Ubicación seleccionada para crear la observación
  LatLng? _selectedPoint;

  // Ubicación actual del dispositivo
  LatLng? _currentLocation;

  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSubscription;

  bool _isGettingLocation = true;

  // Ubicación de respaldo mientras se obtiene el GPS
  static const LatLng _initialCenter =
      LatLng(4.0925, -76.1813);

  @override
  void initState() {
    super.initState();

    _getCurrentLocation();
    _startLocationTracking();
  }

  // ==========================================================
  // OBTENER UBICACIÓN ACTUAL
  // ==========================================================

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint('El servicio de ubicación está desactivado');

        if (mounted) {
          setState(() {
            _isGettingLocation = false;
          });
        }

        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        debugPrint('Permiso de ubicación denegado');

        if (mounted) {
          setState(() {
            _isGettingLocation = false;
          });
        }

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          'El permiso de ubicación fue denegado permanentemente',
        );

        if (mounted) {
          setState(() {
            _isGettingLocation = false;
          });
        }

        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentLocation = location;

        // Seleccionamos inicialmente la ubicación actual
        // para que el usuario pueda confirmar directamente
        _selectedPoint = location;

        _isGettingLocation = false;
      });

      // Centrar mapa en la ubicación actual
      _mapController.move(location, 17);

      debugPrint(
        'Ubicación actual: '
        '${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');

      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  // ==========================================================
  // SEGUIMIENTO DE UBICACIÓN
  // ==========================================================

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription =
        Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (!mounted) return;

        final location = LatLng(
          position.latitude,
          position.longitude,
        );

        setState(() {
          _currentLocation = location;
        });
      },
      onError: (error) {
        debugPrint(
          'Error en seguimiento de ubicación: $error',
        );
      },
    );
  }

  // ==========================================================
  // AL TOCAR EL MAPA
  // ==========================================================

  void _onMapTap(
    TapPosition tapPosition,
    LatLng point,
  ) {
    setState(() {
      _selectedPoint = point;
    });
  }

  // ==========================================================
  // VOLVER A MI UBICACIÓN
  // ==========================================================

  void _goToCurrentLocation() {
    if (_currentLocation == null) return;

    _mapController.move(
      _currentLocation!,
      17,
    );
  }

  // ==========================================================
  // FORMATEAR COORDENADAS
  // ==========================================================

  String _formatCoords(LatLng point) {
    return '${point.latitude.toStringAsFixed(6)}, '
        '${point.longitude.toStringAsFixed(6)}';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // ====================================================
          // MAPA
          // ====================================================

          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _currentLocation ?? _initialCenter,
              initialZoom: 15,
              onTap: _onMapTap,
            ),
            children: [

              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.app_tesis',
              ),

              // =================================================
              // MARCADORES
              // =================================================

              MarkerLayer(
                markers: [

                  // ---------------------------------------------
                  // UBICACIÓN ACTUAL DEL DISPOSITIVO
                  // ---------------------------------------------

                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(
                              alpha: 0.20,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ---------------------------------------------
                  // UBICACIÓN SELECCIONADA PARA LA OBSERVACIÓN
                  // ---------------------------------------------

                  if (_selectedPoint != null)
                    Marker(
                      point: _selectedPoint!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ====================================================
          // APPBAR FLOTANTE
          // ====================================================

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // ====================================================
          // BOTÓN MI UBICACIÓN
          // ====================================================

          Positioned(
            right: 16,
            bottom: 125,
            child: FloatingActionButton.small(
              heroTag: 'current_location',
              backgroundColor: Colors.white,
              onPressed: _currentLocation == null
                  ? _getCurrentLocation
                  : _goToCurrentLocation,
              child: const Icon(
                Icons.my_location,
                color: Colors.blue,
              ),
            ),
          ),

          // ====================================================
          // MENSAJE MIENTRAS SE OBTIENE GPS
          // ====================================================

          if (_isGettingLocation)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Obteniendo ubicación...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ====================================================
          // CONFIRMAR UBICACIÓN
          // ====================================================

          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Column(
              children: [

                if (_selectedPoint != null)
                  Container(
                    margin:
                        const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _formatCoords(_selectedPoint!),
                      style:
                          const TextStyle(fontSize: 12),
                    ),
                  ),

                ElevatedButton(
                  onPressed: _selectedPoint == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ObservationCategoryScreen(
                                location: _selectedPoint!,
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color.fromARGB(
                      255,
                      7,
                      83,
                      11,
                    ),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.grey.shade400,
                    minimumSize:
                        const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirmar ubicación',
                    style: TextStyle(fontSize: 15),
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


/*import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'observation_category_screen.dart';

class ObservationMapScreen extends StatefulWidget {
  const ObservationMapScreen({super.key});

  @override
  State<ObservationMapScreen> createState() => _ObservationMapScreenState();
}

class _ObservationMapScreenState extends State<ObservationMapScreen> {
  LatLng? _selectedPoint;
  final MapController _mapController = MapController();

  // Coordenadas iniciales (ajusta a tu ciudad)
  static const LatLng _initialCenter = LatLng(4.0925, -76.1813); // Tuluá, Valle

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() => _selectedPoint = point);
  }

  String _formatCoords(LatLng point) {
    return 'UTM ${point.latitude.toStringAsFixed(4)} '
        '${point.longitude.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 15,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app_tesis',
              ),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── AppBar flotante ───────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // ── Botón Confirmar ubicación ─────────────────────────
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Column(
              children: [
                if (_selectedPoint != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Text(
                      _formatCoords(_selectedPoint!),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _selectedPoint == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ObservationCategoryScreen(
                                location: _selectedPoint!,
                              ),
                            ),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 7, 83, 11),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirmar ubicación',
                      style: TextStyle(fontSize: 15)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}*/