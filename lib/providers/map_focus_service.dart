import 'package:flutter/foundation.dart';

/// Petición para centrar el mapa en unas coordenadas específicas.
class MapFocusRequest {
  final double latitude;
  final double longitude;
  final double zoom;
  final String? reporteId;

  const MapFocusRequest({
    required this.latitude,
    required this.longitude,
    this.zoom = 16.0,
    this.reporteId,
  });
}

/// Servicio singleton que actúa como canal de comunicación entre cualquier
/// pantalla y el mapa principal. Al presionar "Ver en el mapa", la pantalla
/// establece una [MapFocusRequest] aquí; [HomeMapScreen] la consume al
/// recuperar el foco y anima la cámara a las coordenadas.
class MapFocusService {
  MapFocusService._();
  static final MapFocusService instance = MapFocusService._();

  final ValueNotifier<MapFocusRequest?> pendingFocus =
      ValueNotifier<MapFocusRequest?>(null);

  /// Solicita centrar el mapa en [lat], [lng] con el [zoom] indicado.
  void requestFocus({
    required double lat,
    required double lng,
    double zoom = 16.0,
    String? reporteId,
  }) {
    pendingFocus.value = MapFocusRequest(
      latitude: lat,
      longitude: lng,
      zoom: zoom,
      reporteId: reporteId,
    );
  }

  /// Marca la solicitud como consumida.
  void consume() {
    pendingFocus.value = null;
  }
}
