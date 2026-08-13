import 'dart:io';
import 'dart:convert';
import 'package:app_tesis/screens/observations/observation_discard_dialog.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_tesis/screens/login_screen/auth_service.dart';
import 'package:http_parser/http_parser.dart';

class ObservationFormScreen extends StatefulWidget {
  final LatLng location;
  final String category;

  const ObservationFormScreen({
    super.key,
    required this.location,
    required this.category,
  });

  @override
  State<ObservationFormScreen> createState() => _ObservationFormScreenState();
}

class _ObservationFormScreenState extends State<ObservationFormScreen> {
  static const _baseUrl = 'http://10.0.2.2:8080';

  final _typeController = TextEditingController();
  final _descController = TextEditingController();
  List<File> _photos = [];

  // Catálogos del backend
  List<dynamic> _prioridades = [];
  List<dynamic> _estadosReporte = [];
  int? _selectedPrioridadId;
  int? _selectedEstadoId;
  int? _categoriaId; // Se resuelve buscando por nombre

  bool _loadingCatalogos = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCatalogos();
  }

  String _priorityImage(String nombre) {
    switch (nombre.trim()) {
      case 'Alta':
        return 'assets/images/Alta.png';
      case 'Media':
        return 'assets/images/media.png';
      case 'Baja':
        return 'assets/images/Baja.png';
      default:
        return ''; // las demás no tienen imagen
    }
  }

  Color _priorityColor(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('alta') || n.contains('crítica') || n.contains('critica')) {
      return Colors.red.shade600;
    } else if (n.contains('baja')) {
      return const Color.fromARGB(255, 7, 83, 11);
    }
    return Colors.orange.shade600;
  }

  // ── Cargar catálogos del backend ───────────────────────────
  Future<void> _loadCatalogos() async {
    try {
      final token = await AuthService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/prioridades'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/estados-reporte'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/categorias'), headers: headers),
      ]);

      if (!mounted) return;

      final prioridades = jsonDecode(results[0].body) as List;
      prioridades.sort(
        (a, b) => (b['nivel'] as int).compareTo(a['nivel'] as int),
      );
      final estados = jsonDecode(results[1].body) as List;
      final categorias = jsonDecode(results[2].body) as List;

      // Buscar el ID de la categoría por nombre
      final catMatch = categorias.firstWhere(
        (c) =>
            (c['nombre'] as String).toLowerCase() ==
            widget.category.toLowerCase(),
        orElse: () => null,
      );

      setState(() {
        _prioridades = prioridades;
        _estadosReporte = estados;
        _categoriaId = catMatch != null ? catMatch['id'] as int : null;
        _loadingCatalogos = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCatalogos = false;
          _errorMessage = 'Error cargando catálogos: $e';
        });
      }
    }
  }

  // ── Foto ───────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _photos.add(File(picked.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
  /*Future<void> _pickPhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _photo = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }*/

  // ── Guardar observación → POST /api/reportes ───────────────
  Future<void> _saveObservation() async {
    if (_typeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el tipo de animal/especie')),
      );
      return;
    }

    if (_selectedPrioridadId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una prioridad')));
      return;
    }

    if (_categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró la categoría')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/reportes'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      //==============================
      // Datos del reporte
      //==============================
      request.fields['titulo'] = _typeController.text.trim();
      request.fields['descripcion'] = _descController.text.trim();
      request.fields['categoriaId'] = _categoriaId.toString();
      request.fields['prioridadId'] = _selectedPrioridadId.toString();
      request.fields['latitud'] = widget.location.latitude.toString();

      request.fields['longitud'] = widget.location.longitude.toString();

      request.fields['fuente'] = 'mobile';

      /*
      //==============================
      // Imágenes
      //==============================
      for (int i = 0; i < _photos.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath('evidencias', _photos[i].path),
        );
      }*/

      //==============================
// Imágenes
//==============================
for (int i = 0; i < _photos.length; i++) {
  final file = _photos[i];

  final extension = file.path.split('.').last.toLowerCase();

  String mimeType = 'image/jpeg';

  if (extension == 'png') {
    mimeType = 'image/png';
  } else if (extension == 'webp') {
    mimeType = 'image/webp';
  } else if (extension == 'jpg' || extension == 'jpeg') {
    mimeType = 'image/jpeg';
  }

  request.files.add(
    await http.MultipartFile.fromPath(
      'evidencias',
      file.path,
      filename: file.path.split('/').last,
      contentType: MediaType.parse(mimeType),
    ),
  );
}

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("STATUS: ${response.statusCode}");
      debugPrint("BODY: ${response.body}");

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observación guardada exitosamente'),
            backgroundColor: const Color.fromARGB(255, 7, 83, 11),
          ),
        );

        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        setState(() {
          _errorMessage = response.body;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _errorMessage = e.toString();
      });
    }
  }

  /*Future<void> _saveObservation() async {
    if (_typeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el tipo de animal/especie')),
      );
      return;
    }
    if (_selectedPrioridadId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una prioridad')));
      return;
    }
    /*if (_selectedEstadoId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un estado')));
      return;
    }*/
    if (_categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró la categoría en el backend'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();

      // Convertir foto a Base64 si existe
      List<Map<String, dynamic>> evidencias = [];
      for (int i = 0; i < _photos.length; i++) {
        final bytes = await _photos[i].readAsBytes();
        final base64Image = base64Encode(bytes);
        evidencias.add({
          'archivoBase64': base64Image,
          'tipoArchivo': 'imagen',
          'mimeType': 'image/jpeg',
          'esPrincipal': i == 0, // solo la primera es principal
          'tamanoArchivo': bytes.length,
          'descripcion': 'Foto ${i + 1}',
        });
      }
      /*List<Map<String, dynamic>> evidencias = [];
      if (_photo != null) {
        final bytes = await _photo!.readAsBytes();
        final base64Image = base64Encode(bytes);
        evidencias.add({
          'archivoBase64': base64Image,
          'tipoArchivo': 'imagen',
          'mimeType': 'image/jpeg',
          'esPrincipal': true,
          'tamanoArchivo': bytes.length,
          'descripcion': 'Foto principal',
        });
      }*/

      final body = jsonEncode({
        'categoriaId': _categoriaId,
        'prioridadId': _selectedPrioridadId,
        'estadoReporteId': _selectedEstadoId,
        'titulo': _typeController.text.trim(),
        'descripcion': _descController.text.trim(),
        'fechaEvento': DateTime.now().toIso8601String(),
        'fuente': 'mobile',
        'latitud': widget.location.latitude,
        'longitud': widget.location.longitude,
        'publico': true,
        'estado': true,
        'evidencias': evidencias,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/api/reportes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('>>> Status: ${response.statusCode}');
      debugPrint('>>> Body: ${response.body}');

      if (!mounted) return;
      setState(() => _saving = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observación guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        final data = jsonDecode(response.body);
        setState(
          () => _errorMessage =
              data['message'] ?? 'Error al guardar la observación',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Error de conexión: $e';
        });
      }
    }
  }*/

  /*Future<void> _saveObservation() async {
    if (_typeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el tipo de animal/especie')),
      );
      return;
    }
    if (_selectedPrioridadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una prioridad')),
      );
      return;
    }
    if (_selectedEstadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un estado')),
      );
      return;
    }
    if (_categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No se encontró la categoría en el backend')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      final body = jsonEncode({
        'categoriaId': _categoriaId,
        'prioridadId': _selectedPrioridadId,
        'estadoReporteId': _selectedEstadoId,
        'titulo': _typeController.text.trim(),
        'descripcion': _descController.text.trim(),
        'fechaEvento': DateTime.now().toIso8601String(),
        'fuente': 'mobile',
        'latitud': widget.location.latitude,
        'longitud': widget.location.longitude,
        'fotoPrincipalUrl': _photo?.path ?? '',
        'publico': true,
        'estado': true,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/api/reportes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (!mounted) return;
      setState(() => _saving = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observación guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage =
            data['message'] ?? 'Error al guardar la observación');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Error de conexión: $e';
        });
      }
    }
  }*/

  // ── Diálogo de descarte ────────────────────────────────────
  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => DiscardObservationDialog(
        onDiscard: () => Navigator.pop(ctx, true),
        onContinue: () => Navigator.pop(ctx, false),
      ),
    );
  }

  String _formatCoords() =>
      'UTM ${widget.location.latitude.toStringAsFixed(4)} '
      '${widget.location.longitude.toStringAsFixed(4)}';

  String _categoryImage(String category) {
    const map = {
      'Fauna': 'assets/images/Oso de anteojos-2.jpeg',
      'Flora': 'assets/images/Flora.jpeg',
      'Agua': 'assets/images/Agua.jpeg',
      'Aire': 'assets/images/Aire.jpeg',
      'Suelo': 'assets/images/Suelo.jpeg',
    };
    return map[category] ?? 'assets/images/Oso de anteojos-2.jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _showDiscardDialog();
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final leave = await _showDiscardDialog();
              if (leave == true && context.mounted) Navigator.pop(context);
            },
          ),
          title: const Text('Observación'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.check_circle,
                  color: const Color.fromARGB(255, 7, 83, 11),
                  size: 28,
                ),
                onPressed: _saveObservation,
              ),
          ],
        ),
        body: _loadingCatalogos
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Categoría y coordenadas ──────────────
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            _categoryImage(widget.category),
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 13,
                                  color: Colors.grey.shade500,
                                ),
                                Text(
                                  _formatCoords(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cambiar',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // ── Tipo de animal/especie ────────────────
                    TextField(
                      controller: _typeController,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de animal / especie',
                        hintText: 'Ej: Puma andino',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Descripción ───────────────────────────
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Prioridad desde backend ───────────────────────────────
                    const Text(
                      'Prioridad',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ..._prioridades.map((p) {
                      final nombre = p['nombre'].toString();
                      final isSelected = _selectedPrioridadId == p['id'] as int;
                      return GestureDetector(
                        onTap: () => setState(
                          () => _selectedPrioridadId = p['id'] as int,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green.shade50
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color.fromARGB(255, 7, 83, 11)
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Imagen de prioridad
                              _priorityImage(nombre).isNotEmpty
                                  ? Image.asset(
                                      _priorityImage(nombre),
                                      width: 40,
                                      height: 40,
                                    )
                                  : Icon(
                                      Icons.flag_outlined,
                                      color: Colors.grey.shade400,
                                      size: 32,
                                    ),
                              const SizedBox(width: 12),
                              Text(
                                nombre,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color.fromARGB(255, 7, 83, 11)
                                      : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: const Color.fromARGB(255, 7, 83, 11),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    /*const Text(
                      'Prioridad',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ..._prioridades.map(
                      (p) => RadioListTile<int>(
                        value: p['id'] as int,
                        groupValue: _selectedPrioridadId,
                        title: Text(p['nombre']),
                        dense: true,
                        activeColor: Colors.green.shade600,
                        onChanged: (v) =>
                            setState(() => _selectedPrioridadId = v),
                      ),
                    ),
                    const SizedBox(height: 16),*/

                    // ── Estado desde backend ──────────────────
                    /*const Text(
                      'Estado',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedEstadoId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      hint: const Text('Selecciona un estado'),
                      items: _estadosReporte
                          .map(
                            (e) => DropdownMenuItem<int>(
                              value: e['id'] as int,
                              child: Text(e['nombre']),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedEstadoId = v),
                    ),
                    const SizedBox(height: 16),*/

                    // ── Error de conexión ─────────────────────
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Foto ──────────────────────────────────
                    /*const Text(
                      'Foto',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: _photo != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_photo!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 40,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Toca para añadir foto',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),*/

                    // ── Fotos ─────────────────────────────────────────────────
                    const Text(
                      'Fotos',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),

                    if (_photos.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _photos.length,
                        itemBuilder: (ctx, i) => Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_photos[i], fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _photos.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (i == 0)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(255, 7, 83, 11),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Principal',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 24,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _photos.isEmpty
                                  ? 'Agregar foto'
                                  : 'Agregar otra foto',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }
}

/*import 'dart:io';
import 'package:app_tesis/screens/observations/observation_discard_dialog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
//import 'package:permission_handler/permission_handler.dart';

class ObservationFormScreen extends StatefulWidget {
  final LatLng location;
  final String category;

  const ObservationFormScreen({
    super.key,
    required this.location,
    required this.category,
  });

  @override
  State<ObservationFormScreen> createState() => _ObservationFormScreenState();
}

class _ObservationFormScreenState extends State<ObservationFormScreen> {
  final _typeController = TextEditingController();
  final _descController = TextEditingController();
  File? _photo;
  String _priority = 'Prioridad media';

  final List<String> _priorities = [
    'Prioridad alta',
    'Prioridad media',
    'Prioridad baja',
  ];

  String _categoryImage(String category) {
  const map = {
    'Fauna': 'assets/images/Oso de anteojos-2.jpeg',
    'Flora': 'assets/images/Flora.jpeg',
    'Agua':  'assets/images/Agua.jpeg',
    'Aire':  'assets/images/Aire.jpeg',
    'Suelo': 'assets/images/Suelo.jpeg',
  };
  return map[category] ?? 'assets/images/Oso de anteojos-2.jpeg';
}

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seleccionar foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null && mounted) {
        setState(() => _photo = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
  /*Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) setState(() => _photo = File(picked.path));
  }*/

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => DiscardObservationDialog(
        onDiscard: () => Navigator.pop(ctx, true),
        onContinue: () => Navigator.pop(ctx, false),
      ),
    );
  }

  void _saveObservation() {
    if (_typeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el tipo de animal/especie')),
      );
      return;
    }
    // TODO: Guardar en tu backend/base de datos
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Observación guardada'),
        backgroundColor: Colors.green,
      ),
    );
    // Volver al inicio de observaciones
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  String _formatCoords() =>
      'UTM ${widget.location.latitude.toStringAsFixed(4)} '
      '${widget.location.longitude.toStringAsFixed(4)}';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _showDiscardDialog();
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final leave = await _showDiscardDialog();
              if (leave == true && context.mounted) Navigator.pop(context);
            },
          ),
          title: const Text('Observación'),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
              onPressed: _saveObservation,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Categoría y coordenadas ──────────────────────
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      _categoryImage(widget.category),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          Text(
                            _formatCoords(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cambiar',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // ── Tipo de animal/especie ───────────────────────
              TextField(
                controller: _typeController,
                decoration: const InputDecoration(
                  labelText: 'Tipo de animal',
                  hintText: 'Ej: Coco lega del puma',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Descripción ──────────────────────────────────
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Prioridad ────────────────────────────────────
              const Text(
                'Prioridad',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ..._priorities.map(
                (p) => RadioListTile<String>(
                  value: p,
                  groupValue: _priority,
                  title: Text(p),
                  dense: true,
                  activeColor: Colors.green.shade600,
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ),
              const SizedBox(height: 16),

              // ── Foto ─────────────────────────────────────────
              const Text('Foto', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: _photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_photo!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Toca para añadir foto',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}*/
