import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'report_service.dart';

class ReportMapScreen extends StatefulWidget {
  const ReportMapScreen({super.key});

  @override
  State<ReportMapScreen> createState() => _ReportMapScreenState();
}

class _ReportMapScreenState extends State<ReportMapScreen> {
  final MapController _mapController = MapController();
  static const LatLng _initialCenter = LatLng(4.0925, -76.1813);

  List<dynamic> _reportes = [];
  List<dynamic> _categorias = [];
  int? _selectedCategoriaId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final reportes = await ReportService.getReportes();
    final categorias = await ReportService.getCategorias();
    if (mounted) {
      setState(() {
        _reportes = reportes;
        _categorias = categorias;
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredReportes {
    if (_selectedCategoriaId == null) return _reportes;
    return _reportes
        .where((r) => r['categoriaId'] == _selectedCategoriaId)
        .toList();
  }

  void _openCreateReport() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateReportSheet(
        categorias: _categorias,
        initialLocation: _initialCenter,
      ),
    );
    if (result == true) _loadData();
  }

  void _showReportDetail(Map<String, dynamic> reporte) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReportDetailSheet(reporte: reporte),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Mapa ──────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app_tesis',
              ),
              MarkerLayer(
                markers: _filteredReportes
                    .where((r) =>
                        r['latitud'] != null && r['longitud'] != null)
                    .map((r) => Marker(
                          point: LatLng(
                            r['latitud'].toDouble(),
                            r['longitud'].toDouble(),
                          ),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showReportDetail(r),
                            child: Icon(
                              Icons.location_pin,
                              color: _priorityColor(r['prioridadNombre']),
                              size: 36,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),

          // ── AppBar flotante ───────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Título
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: const Text('Reportes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  const Spacer(),
                  // Botón refresh
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),
          ),

          // ── Filtro por categoría ──────────────────────────
          if (_categorias.isNotEmpty)
            Positioned(
              top: 80,
              left: 12,
              right: 12,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      isSelected: _selectedCategoriaId == null,
                      onTap: () =>
                          setState(() => _selectedCategoriaId = null),
                    ),
                    ..._categorias.map((cat) => _FilterChip(
                          label: cat['nombre'],
                          isSelected:
                              _selectedCategoriaId == cat['id'],
                          onTap: () => setState(
                              () => _selectedCategoriaId = cat['id']),
                        )),
                  ],
                ),
              ),
            ),

          // ── Loading ───────────────────────────────────────
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          // ── Contador de reportes ──────────────────────────
          Positioned(
            bottom: 100,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ],
              ),
              child: Text(
                '${_filteredReportes.length} reporte${_filteredReportes.length != 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),

      // ── FAB crear reporte ─────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateReport,
        backgroundColor: Colors.green[800],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo reporte',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ─── Chip de filtro ──────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[800] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2))
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Sheet detalle de reporte ────────────────────────────────────────────────

class _ReportDetailSheet extends StatelessWidget {
  final Map<String, dynamic> reporte;

  const _ReportDetailSheet({required this.reporte});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          Text(reporte['titulo'] ?? '',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Chips de info
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(
                  icon: Icons.category,
                  label: reporte['categoriaNombre'] ?? ''),
              _InfoChip(
                  icon: Icons.flag,
                  label: reporte['prioridadNombre'] ?? ''),
              _InfoChip(
                  icon: Icons.info_outline,
                  label: reporte['estadoReporteNombre'] ?? ''),
            ],
          ),
          const SizedBox(height: 12),

          // Descripción
          if (reporte['descripcion'] != null &&
              reporte['descripcion'].toString().isNotEmpty)
            Text(reporte['descripcion'],
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 14)),
          const SizedBox(height: 8),

          // Coordenadas
          Row(
            children: [
              Icon(Icons.location_on,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                '${reporte['latitud']?.toStringAsFixed(4)}, '
                '${reporte['longitud']?.toStringAsFixed(4)}',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.green.shade700)),
        ],
      ),
    );
  }
}

// ─── Sheet crear reporte ─────────────────────────────────────────────────────

class _CreateReportSheet extends StatefulWidget {
  final List<dynamic> categorias;
  final LatLng initialLocation;

  const _CreateReportSheet({
    required this.categorias,
    required this.initialLocation,
  });

  @override
  State<_CreateReportSheet> createState() => _CreateReportSheetState();
}

class _CreateReportSheetState extends State<_CreateReportSheet> {
  final _tituloController = TextEditingController();
  final _descController = TextEditingController();
  final _direccionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<dynamic> _prioridades = [];
  List<dynamic> _estados = [];
  int? _selectedCategoriaId;
  int? _selectedPrioridadId;
  int? _selectedEstadoId;
  File? _photo;
  bool _isLoading = false;
  bool _loadingCatalogos = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    final prioridades = await ReportService.getPrioridades();
    final estados = await ReportService.getEstadosReporte();
    if (mounted) {
      setState(() {
        _prioridades = prioridades;
        _estados = estados;
        _loadingCatalogos = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: Colors.blue),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoriaId == null ||
        _selectedPrioridadId == null ||
        _selectedEstadoId == null) {
      setState(() =>
          _errorMessage = 'Selecciona categoría, prioridad y estado');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // TODO: subir foto a storage y obtener URL real
    // Por ahora se envía vacío si no hay foto
    final fotoUrl = _photo != null ? _photo!.path : '';

    final result = await ReportService.createReporte(
      categoriaId: _selectedCategoriaId!,
      prioridadId: _selectedPrioridadId!,
      estadoReporteId: _selectedEstadoId!,
      titulo: _tituloController.text.trim(),
      descripcion: _descController.text.trim(),
      latitud: widget.initialLocation.latitude,
      longitud: widget.initialLocation.longitude,
      direccionReferencia: _direccionController.text.trim(),
      fotoPrincipalUrl: fotoUrl,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reporte creado exitosamente'),
            backgroundColor: Colors.green),
      );
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _loadingCatalogos
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Encabezado
                    Row(
                      children: [
                        const Text('Nuevo reporte',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Título ──────────────────────────────
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Ingresa un título' : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Descripción ─────────────────────────
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Ingresa una descripción' : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Categoría ───────────────────────────
                    DropdownButtonFormField<int>(
                      value: _selectedCategoriaId,
                      decoration: const InputDecoration(
                        labelText: 'Categoría *',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.categorias
                          .map((c) => DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(c['nombre']),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCategoriaId = v),
                      validator: (v) =>
                          v == null ? 'Selecciona una categoría' : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Prioridad ───────────────────────────
                    DropdownButtonFormField<int>(
                      value: _selectedPrioridadId,
                      decoration: const InputDecoration(
                        labelText: 'Prioridad *',
                        border: OutlineInputBorder(),
                      ),
                      items: _prioridades
                          .map((p) => DropdownMenuItem<int>(
                                value: p['id'] as int,
                                child: Text(p['nombre']),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedPrioridadId = v),
                      validator: (v) =>
                          v == null ? 'Selecciona una prioridad' : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Estado ──────────────────────────────
                    DropdownButtonFormField<int>(
                      value: _selectedEstadoId,
                      decoration: const InputDecoration(
                        labelText: 'Estado *',
                        border: OutlineInputBorder(),
                      ),
                      items: _estados
                          .map((e) => DropdownMenuItem<int>(
                                value: e['id'] as int,
                                child: Text(e['nombre']),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedEstadoId = v),
                      validator: (v) =>
                          v == null ? 'Selecciona un estado' : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Dirección referencia ────────────────
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección de referencia',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Foto ────────────────────────────────
                    const Text('Foto',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.shade300),
                        ),
                        child: _photo != null
                            ? ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(12),
                                child: Image.file(_photo!,
                                    fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt,
                                      size: 36,
                                      color: Colors.grey.shade400),
                                  const SizedBox(height: 6),
                                  Text('Toca para añadir foto',
                                      style: TextStyle(
                                          color:
                                              Colors.grey.shade500,
                                          fontSize: 13)),
                                ],
                              ),
                      ),
                    ),

                    // ── Error ───────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: TextStyle(
                                      color: Colors.red.shade700)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Botón enviar ────────────────────────
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Crear reporte',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}