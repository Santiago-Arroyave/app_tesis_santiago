import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:goblink_park/screens/reports/review_report_screen.dart';

class ReportLocationScreen extends StatefulWidget {
  final String category;
  final String title;
  final String description;
  final DateTime dateTime;
  final String priority;
  final List<File> photos;
  final Map<String, dynamic> specificData;

  const ReportLocationScreen({
    super.key,
    required this.category,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.priority,
    required this.photos,
    required this.specificData,
  });

  @override
  State<ReportLocationScreen> createState() => _ReportLocationScreenState();
}

class _ReportLocationScreenState extends State<ReportLocationScreen> {
  static const _defaultCenter = LatLng(4.1151, -76.1976); // PNR Páramo del Duende
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();
  bool _gettingGPS = false;

  final TextEditingController _sectorController = TextEditingController();
  final TextEditingController _municipioController =
      TextEditingController(text: 'Tuluá, Valle del Cauca');

  @override
  void initState() {
    super.initState();
    _selectedLocation = _defaultCenter;
    _getCurrentGPSLocation();
  }

  @override
  void dispose() {
    _sectorController.dispose();
    _municipioController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentGPSLocation() async {
    setState(() => _gettingGPS = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _gettingGPS = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _gettingGPS = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final loc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _selectedLocation = loc;
          _gettingGPS = false;
        });
        _mapController.move(loc, 15.5);
      }
    } catch (_) {
      if (mounted) setState(() => _gettingGPS = false);
    }
  }

  String _formatWGS84(LatLng latLng) {
    final lat = latLng.latitude;
    final lng = latLng.longitude;
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}° $latDir, ${lng.abs().toStringAsFixed(4)}° $lngDir';
  }

  Future<void> _onConfirmLocation() async {
    if (_sectorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa el sector')),
      );
      return;
    }

    if (_municipioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa el municipio')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewReportScreen(
          category: widget.category,
          title: widget.title,
          description: widget.description,
          dateTime: widget.dateTime,
          priority: widget.priority,
          photos: widget.photos,
          specificData: widget.specificData,
          location: _selectedLocation,
          sector: _sectorController.text.trim(),
          municipio: _municipioController.text.trim(),
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F3A22);

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: isDark ? Colors.white : const Color(0xFF0F3A22),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Ubicación geográfica",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F3A22),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(3, "Ubicación geográfica", isDark: isDark),
                    const SizedBox(height: 12),
                    Text(
                      "Punto de observación",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Toca el mapa o usa el GPS para ubicar con precisión el hallazgo",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mapa Satelital Interactivo
                    _buildMapContainer(),
                    const SizedBox(height: 12),

                    // Coordenadas en tiempo real y botón GPS
                    _buildCoordinatesCard(cardBg, isDark),
                    const SizedBox(height: 14),

                    // Sector del Páramo
                    _buildSectorDropdown(cardBg, isDark),
                    const SizedBox(height: 14),

                    // Municipio
                    _buildMunicipioField(cardBg, isDark),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int currentStep, String stepTitle, {bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            final stepNum = index + 1;
            final isDone = stepNum < currentStep;
            final isCurrent = stepNum == currentStep;
            final color = isDone || isCurrent
                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF1E5E3A))
                : (isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB));

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          "Paso $currentStep de 4 • $stepTitle",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF1E5E3A),
          ),
        ),
      ],
    );
  }

  Widget _buildMapContainer() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E5E3A).withAlpha(80), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 14.5,
                onTap: (_, point) {
                  setState(() => _selectedLocation = point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.app_tesis',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 50,
                      height: 50,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 36, color: Color(0xFFEF4444)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _getCurrentGPSLocation,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: _gettingGPS
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E5E3A)),
                          )
                        : const Icon(Icons.my_location, color: Color(0xFF1E5E3A), size: 20),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Toca cualquier punto del mapa para ajustar la posición",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinatesCard(Color cardBg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.gps_fixed, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Coordenadas WGS84",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatWGS84(_selectedLocation),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _getCurrentGPSLocation,
            icon: const Icon(Icons.near_me, size: 14, color: Color(0xFF1E5E3A)),
            label: const Text(
              "Mi GPS",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E5E3A)),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              backgroundColor: const Color(0xFFE8F5E9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorDropdown(Color cardBg, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Sector *",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
          child: TextFormField(
            controller: _sectorController,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
            decoration: InputDecoration(
              hintText: 'Escribe el sector... (ej. Laguna Verde, Cuenca Alta)',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              ),
              prefixIcon: const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF1E5E3A),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'El sector es obligatorio' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMunicipioField(Color cardBg, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Municipio / Jurisdicción *",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
          child: TextFormField(
            controller: _municipioController,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
            decoration: const InputDecoration(
              hintText: "Ej. Tuluá, Valle del Cauca",
              hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
              prefixIcon: Icon(Icons.location_city_outlined, size: 20, color: Color(0xFF6B7280)),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _onConfirmLocation,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E5E3A),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Confirmar ubicación",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
