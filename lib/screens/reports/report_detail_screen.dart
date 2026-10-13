import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/reports/edit_report_screen.dart';
import 'package:goblink_park/widgets/notification_bell_button.dart';

class ReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> reporte;

  const ReportDetailScreen({
    super.key,
    required this.reporte,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  static const _baseUrl = ApiConfig.baseUrl;

  late Map<String, dynamic> _reporte;
  List<Map<String, dynamic>> _imagesList = [];
  bool _canEdit = true;

  @override
  void initState() {
    super.initState();
    _reporte = Map<String, dynamic>.from(widget.reporte);
    _extractImages();
    _checkAuthorPermission();
    _cargarDetalleReporte();
  }

  Future<void> _cargarDetalleReporte() async {
    final reportId = _reporte['id'] ?? widget.reporte['id'];
    if (reportId == null) return;

    try {
      final token = await AuthStorage.getToken();
      final cleanToken = (token ?? '').trim().startsWith('Bearer ')
          ? (token ?? '').trim().substring(7).trim()
          : (token ?? '').trim();

      final response = await http.get(
        Uri.parse('$_baseUrl/api/reportes/$reportId'),
        headers: {
          'Content-Type': 'application/json',
          if (cleanToken.isNotEmpty) 'Authorization': 'Bearer $cleanToken',
        },
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _reporte = decoded;
            _extractImages();
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar detalle del reporte: $e');
    }
  }

  Future<void> _checkAuthorPermission() async {
    try {
      final user = await AuthStorage.getUserData();
      final currentUserId = await AuthStorage.getUserId();
      final currentUserEmail = await AuthStorage.getEmail();
      final userRol = (user?['rol'] ?? user?['rolNombre'] ?? '').toString().toUpperCase();

      if (userRol.contains('ADMIN') || userRol.contains('COORDINADOR')) {
        if (mounted) setState(() => _canEdit = true);
        return;
      }

      final r = _reporte;
      final reportUserId = r['usuarioId'] ?? r['idUsuario'] ?? r['usuario']?['id'];
      final reportUserEmail = r['usuarioCorreo'] ??
          r['correoUsuario'] ??
          r['usuario']?['correo'] ??
          r['usuario']?['email'];

      if (currentUserId != null && reportUserId != null) {
        if (currentUserId.toString() == reportUserId.toString()) {
          if (mounted) setState(() => _canEdit = true);
          return;
        }
      }
      if (currentUserEmail != null && reportUserEmail != null) {
        if (currentUserEmail.toString().toLowerCase() ==
            reportUserEmail.toString().toLowerCase()) {
          if (mounted) setState(() => _canEdit = true);
          return;
        }
      }
      // Delegar la regla final de autorización al backend
      if (mounted) setState(() => _canEdit = true);
    } catch (_) {
      if (mounted) setState(() => _canEdit = true);
    }
  }

  Future<void> _openEditScreen() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditReportScreen(reporte: _reporte),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _reporte = Map<String, dynamic>.from(updated);
        _extractImages();
      });
      await _cargarDetalleReporte();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte actualizado correctamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _extractImages() {
    final list = <Map<String, dynamic>>[];
    final r = _reporte;

    // 1. Foto principal registrada por el usuario
    final fotoPrincipal = r['fotoPrincipalUrl'] ?? r['fotoUrl'] ?? r['imagenUrl'] ?? r['urlFoto'] ?? r['foto'];
    if (fotoPrincipal != null && fotoPrincipal.toString().trim().isNotEmpty) {
      list.add({
        'data': fotoPrincipal.toString().trim(),
        'titulo': 'Evidencia Principal',
        'subtitulo': 'Registro en campo',
      });
    }

    // 2. Evidencias complementarias registradas (ignorando las marcadas como eliminadas)
    final evidencias = r['evidencias'];
    if (evidencias is List && evidencias.isNotEmpty) {
      for (int i = 0; i < evidencias.length; i++) {
        final ev = evidencias[i];
        if (ev is Map) {
          if (ev['eliminar'] == true) continue;
          final b64 = ev['archivoUrl'] ?? ev['url'] ?? ev['urlArchivo'] ?? ev['fotoUrl'] ?? ev['archivoBase64'];
          if (b64 != null && b64.toString().trim().isNotEmpty) {
            final trimmed = b64.toString().trim();
            // Evitar duplicar la foto principal si tiene la misma URL
            if (fotoPrincipal != null && trimmed == fotoPrincipal.toString().trim()) {
              continue;
            }
            list.add({
              'data': trimmed,
              'titulo': ev['titulo']?.toString().isNotEmpty == true
                  ? ev['titulo'].toString()
                  : 'Evidencia ${list.length + 1}',
              'subtitulo': ev['descripcion']?.toString().isNotEmpty == true
                  ? ev['descripcion'].toString()
                  : 'Detalle de observación',
            });
          }
        }
      }
    }

    _imagesList = list;
  }

  String _getCategoryAsset(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (c.contains('fauna') || c.contains('animal')) {
      return 'assets/images/Fauna.jpg';
    }
    if (c.contains('agua') || c.contains('hídric')) {
      return 'assets/images/Agua.jpg';
    }
    if (c.contains('aire') || c.contains('clima')) {
      return 'assets/images/Aire.jpg';
    }
    if (c.contains('suelo') || c.contains('tierra')) {
      return 'assets/images/Suelo.jpg';
    }
    return 'assets/images/Flora.jpg';
  }

  Color _getCategoryColor(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (c.contains('fauna') || c.contains('animal')) return const Color(0xFF9A6735);
    if (c.contains('flora') || c.contains('vegetal')) return const Color(0xFF1E5E3A);
    if (c.contains('suelo') || c.contains('tierra')) return const Color(0xFF8C5E48);
    if (c.contains('agua') || c.contains('hídric')) return const Color(0xFF2563EB);
    if (c.contains('aire') || c.contains('clima')) return const Color(0xFF0284C7);
    return const Color(0xFF1E5E3A);
  }

  IconData _getCategoryIcon(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (c.contains('fauna') || c.contains('animal')) return Icons.pets;
    if (c.contains('agua') || c.contains('hídric')) return Icons.water_drop;
    if (c.contains('suelo') || c.contains('tierra')) return Icons.landscape;
    if (c.contains('aire') || c.contains('clima')) return Icons.air;
    return Icons.eco;
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

  String _formatDate(dynamic dateVal) {
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

  void _openFullScreenViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          images: _imagesList,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildImageWidget(Map<String, dynamic> item, {BoxFit fit = BoxFit.cover}) {
    if (item.containsKey('asset')) {
      return Image.asset(item['asset'] as String, fit: fit);
    }

    final raw = item['data'] as String?;
    if (raw == null || raw.isEmpty) {
      return Image.asset(_getCategoryAsset(_reporte['categoriaNombre']?.toString()), fit: fit);
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: raw,
        fit: fit,
        memCacheWidth: 600,
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
      );
    }

    try {
      String cleanBase64 = raw;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      final bytes = base64Decode(cleanBase64);
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Image.asset(
          _getCategoryAsset(_reporte['categoriaNombre']?.toString()),
          fit: fit,
        ),
      );
    } catch (_) {
      return Image.asset(
        _getCategoryAsset(_reporte['categoriaNombre']?.toString()),
        fit: fit,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _reporte;
    final catNombre = r['categoriaNombre'] ?? r['categoria']?['nombre'] ?? 'Flora';
    final estadoNombre = r['estadoReporteNombre'] ?? r['estado']?['nombre'] ?? 'Validado';
    final titulo = r['titulo']?.toString().isNotEmpty == true
        ? r['titulo'].toString()
        : 'Observación en PNR Páramo del Duende';

    final int evidenciasCount = _imagesList.length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        bottomNavigationBar: _buildBottomBar(r),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Institucional Fijo
              _buildInstitutionalHeader(),

              // 2. Título de la pantalla: "Detalle del reporte"
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: const Text(
                  "Detalle del reporte",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F3A22),
                    letterSpacing: -0.4,
                  ),
                ),
              ),

              // 3. Barra de Pestañas: [Resumen], [Evidencias (N)], [Seguimiento]
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
                  ),
                ),
                child: TabBar(
                  indicatorColor: const Color(0xFF1E5E3A),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF1E5E3A),
                  unselectedLabelColor: const Color(0xFF6B7280),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
                  tabs: [
                    const Tab(text: "Resumen"),
                    Tab(text: "Evidencias ($evidenciasCount)"),
                    const Tab(text: "Seguimiento"),
                  ],
                ),
              ),

              // 4. Contenido Modular de Pestañas
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTabResumen(r, catNombre, estadoNombre, titulo),
                    _buildTabEvidencias(),
                    _buildTabSeguimiento(r, estadoNombre),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER INSTITUCIONAL FIJO
  // ===========================================================================

  Widget _buildInstitutionalHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F3A22), size: 24),
            onPressed: () => Navigator.pop(context, _reporte),
          ),
          const SizedBox(width: 2),
          ClipOval(
            child: Image.asset(
              'assets/images/Logo verde.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Goblin Park",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F3A22),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  "PNR Páramo del Duende",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E4F3E),
                  ),
                ),
              ],
            ),
          ),
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E5E3A), size: 22),
              tooltip: 'Editar reporte',
              onPressed: _openEditScreen,
            ),
          const NotificationBellButton(),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 1: RESUMEN (Muestra imagen destacada con badge contador)
  // ===========================================================================

  Widget _buildTabResumen(
    Map<String, dynamic> r,
    String catNombre,
    String estadoNombre,
    String titulo,
  ) {
    final catColor = _getCategoryColor(catNombre);
    final statusColor = _getStatusColor(estadoNombre);
    final statusBgColor = _getStatusBgColor(estadoNombre);

    final sector = r['sector'] ?? r['ubicacionTexto'] ?? 'Sector Laguna Verde';
    final municipio = r['municipio'] ?? 'PNR Páramo del Duende (Valle del Cauca)';
    final fecha = _formatDate(r['fechaReporte'] ?? r['fechaCreacion']);
    final autor = r['autorNombre'] ?? r['usuario']?['nombreCompleto'] ?? 'Guardabosques Duende';
    final prioridad = r['prioridadNombre'] ?? r['prioridad']?['nombre'] ?? 'Media';

    final lat = (r['latitud'] as num?)?.toDouble() ?? 3.9123;
    final lng = (r['longitud'] as num?)?.toDouble() ?? -76.6721;
    final coords = '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° W';

    final desc = r['descripcion']?.toString().isNotEmpty == true
        ? r['descripcion'].toString()
        : 'Espécimen registrado durante el recorrido de monitoreo en el páramo. Presenta buen estado de conservación y desarrollo biológico adecuado para las condiciones climáticas del sector.';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen representativa temática de la categoría
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Image.asset(
                _getCategoryAsset(catNombre),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: catColor,
                  child: Icon(_getCategoryIcon(catNombre), size: 48, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Píldoras de Categoría y Estado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: catColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: catColor.withAlpha(100), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getCategoryIcon(catNombre), size: 14, color: catColor),
                    const SizedBox(width: 5),
                    Text(
                      catNombre,
                      style: TextStyle(
                        color: catColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(120), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      estadoNombre,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Título del reporte
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),

          // Descripción detallada
          Text(
            desc,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Tarjeta blanca con borde suave con datos clave
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1E5E3A), size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Datos Clave del Registro",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F3A22),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _buildDataRow(Icons.place_outlined, "Sector", sector),
                const SizedBox(height: 10),
                _buildDataRow(Icons.location_city_outlined, "Municipio", municipio),
                const SizedBox(height: 10),
                _buildDataRow(Icons.calendar_today_outlined, "Fecha y hora", fecha),
                const SizedBox(height: 10),
                _buildDataRow(Icons.person_outline, "Autor", autor),
                const SizedBox(height: 10),
                _buildDataRow(Icons.gps_fixed, "Coordenadas WGS84", coords),
                const SizedBox(height: 10),
                _buildDataRow(
                  Icons.priority_high,
                  "Prioridad",
                  prioridad,
                  badgeColor: prioridad.toLowerCase() == 'alta'
                      ? const Color(0xFFEF4444)
                      : prioridad.toLowerCase() == 'media'
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF1E5E3A),
                ),
              ],
            ),
          ),

          // Tarjeta de Datos Específicos de la Categoría (si existen)
          if (_extractSpecificData(r['datosEspecificos'] ?? r['specificData']).isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getCategoryIcon(catNombre), color: catColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "Información Específica ($catNombre)",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3A22),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  ..._extractSpecificData(r['datosEspecificos'] ?? r['specificData']).entries.map((entry) {
                    final val = entry.value is List
                        ? (entry.value as List).join(', ')
                        : entry.value.toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildDataRow(
                        Icons.check_circle_outline,
                        _capitalize(entry.key),
                        val.isNotEmpty ? val : 'No especificado',
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Map<String, dynamic> _extractSpecificData(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildDataRow(
    IconData icon,
    String label,
    String value, {
    Color? badgeColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: badgeColor != null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: badgeColor.withAlpha(120), width: 1),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PESTAÑA 2: EVIDENCIAS (SIN imagen destacada superior)
  // ===========================================================================

  Widget _buildTabEvidencias() {
    if (_imagesList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                "Sin evidencias fotográficas",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Este reporte no contiene fotografías adjuntas.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Galería de Evidencias",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3A22),
                ),
              ),
              Text(
                "${_imagesList.length} archivo(s)",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cuadrícula de fotos complementarias con bordes redondeados (14)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: _imagesList.length,
            itemBuilder: (ctx, idx) {
              final item = _imagesList[idx];
              return InkWell(
                onTap: () => _openFullScreenViewer(idx),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildImageWidget(item),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['titulo'] ?? 'Evidencia ${idx + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitulo'] ?? 'Vista en campo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 3: SEGUIMIENTO (SIN imagen destacada superior)
  // ===========================================================================

  Widget _buildTabSeguimiento(Map<String, dynamic> r, String estadoNombre) {
    final status = estadoNombre.toLowerCase();
    final isEnviado = true;
    final isEnRevision = status.contains('revis') || status.contains('valid') || status.contains('seguim');
    final isValidado = status.contains('valid') || status.contains('seguim');
    final isEnSeguimiento = status.contains('seguim');

    final fecha = _formatDate(r['fechaReporte'] ?? r['fechaCreacion']);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entidad Supervisora con icono de escudo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFF1E5E3A),
                  radius: 20,
                  child: Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Entidad Supervisora",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Parques Nacionales Naturales de Colombia",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3A22),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          const Text(
            "Línea de Tiempo del Reporte",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F3A22),
            ),
          ),
          const SizedBox(height: 16),

          // Nodos numerados y conectados
          _buildTimelineNode(
            stepNumber: 1,
            title: "Reporte Enviado",
            date: fecha,
            description: "Registrado por el guardabosques con coordenadas GPS y fotografía.",
            isCompleted: isEnviado,
            isCurrent: !isEnRevision,
            isLast: false,
          ),
          _buildTimelineNode(
            stepNumber: 2,
            title: "En Revisión Técnica",
            date: isEnRevision ? "En proceso por el comité biológico" : "Pendiente de asignación",
            description: "Validación taxonómica, estado fenológico y pertinencia ecológica.",
            isCompleted: isEnRevision,
            isCurrent: isEnRevision && !isValidado,
            isLast: false,
          ),
          _buildTimelineNode(
            stepNumber: 3,
            title: "Validado Oficialmente",
            date: isValidado ? "Aprobado por biólogo líder" : "Pendiente de validación",
            description: "Registro incorporado al inventario biológico del PNR Páramo del Duende.",
            isCompleted: isValidado,
            isCurrent: isValidado && !isEnSeguimiento,
            isLast: false,
          ),
          _buildTimelineNode(
            stepNumber: 4,
            title: "En Monitoreo Continuo",
            date: isEnSeguimiento ? "Monitoreo activo" : "Programado para próxima temporada",
            description: "Seguimiento periódico de la población y condiciones del hábitat.",
            isCompleted: isEnSeguimiento,
            isCurrent: isEnSeguimiento,
            isLast: true,
          ),
          const SizedBox(height: 20),

          // Observaciones del Equipo Técnico
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes, color: Color(0xFF1E5E3A), size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Observaciones del Equipo Técnico",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  "Se recomienda mantener el monitoreo visual trimestral y verificar el gradiente de humedad circundante. La especie presenta características óptimas acordes al gradiente altitudinal.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({
    required int stepNumber,
    required String title,
    required String date,
    required String description,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    final activeColor = const Color(0xFF1E5E3A);
    final inactiveColor = const Color(0xFFD1D5DB);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? activeColor : Colors.white,
                border: Border.all(
                  color: isCompleted ? activeColor : inactiveColor,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : Text(
                      stepNumber.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: inactiveColor,
                      ),
                    ),
            ),
            if (!isLast)
              Container(
                width: 2.5,
                height: 52,
                color: isCompleted ? activeColor : inactiveColor,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? const Color(0xFF111827) : const Color(0xFF6B7280),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Actual",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BOTÓN INFERIOR FIJO: "VER EN EL MAPA"
  // ===========================================================================

  Widget _buildBottomBar(Map<String, dynamic> r) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, {
                'action': 'center_on_map',
                'reporte': r,
              });
            },
            icon: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
            label: const Text(
              "Ver en el mapa",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5E3A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// VISOR DE IMÁGENES A PANTALLA COMPLETA INTERACTIVO CON ZOOM
// =============================================================================

class _FullScreenImageViewer extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _renderImage(Map<String, dynamic> item) {
    if (item.containsKey('asset')) {
      return Image.asset(item['asset'] as String, fit: BoxFit.contain);
    }
    final raw = item['data'] as String?;
    if (raw == null || raw.isEmpty) {
      return const Icon(Icons.image_not_supported, color: Colors.white54, size: 60);
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: raw,
        fit: BoxFit.contain,
        memCacheWidth: 600,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white54, size: 60),
      );
    }
    try {
      String cleanBase64 = raw;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      final bytes = base64Decode(cleanBase64);
      return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true);
    } catch (_) {
      return const Icon(Icons.image_not_supported, color: Colors.white54, size: 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.images[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (ctx, index) {
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: _renderImage(widget.images[index]),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "${_currentIndex + 1} / ${widget.images.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['titulo'] ?? 'Evidencia fotográfica',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (item['subtitulo'] != null)
                  Text(
                    item['subtitulo']!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
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
