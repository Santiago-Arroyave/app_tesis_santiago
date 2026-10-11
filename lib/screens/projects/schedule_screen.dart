import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:http_parser/http_parser.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';

class ScheduleScreen extends StatefulWidget {
  final List<dynamic> actividades;
  final String projectName;
  final int projectId;

  const ScheduleScreen({
    super.key,
    required this.actividades,
    required this.projectName,
    required this.projectId,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {

  /*void _openActivity(Map<String, dynamic> actividad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActivityDetailScreen(
          actividad: actividad,
          projectId: widget.projectId,
        ),
      ),
    );
  }*/

  void _openActivity(Map<String, dynamic> actividad) {
    final done = actividad['estado'] == 'completada';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ActivityDetailScreen(
          actividad: actividad,
          projectId: widget.projectId,
          readOnly: done, // ← pasa si es solo lectura
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cronograma',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Actividades',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: widget.actividades.isEmpty
                ? Center(
                    child: Text(
                      'No hay actividades registradas',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.actividades.length,
                    itemBuilder: (_, i) {
                      final act = widget.actividades[i];
                      final done = act['estado'] == 'completada';
                      return InkWell(
                        onTap: () =>
                            _openActivity(Map<String, dynamic>.from(act)),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              // Número
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: done
                                      ? Colors.green.shade600
                                      : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: done
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${i + 1}- ${act['nombre'] ?? act['actividad'] ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${act['fechaInicio'] ?? ''} → ${act['fechaFin'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Imagen preview si tiene
                              if (act['fotoEvidencia'] != null &&
                                  act['fotoEvidencia'].toString().isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: act['fotoEvidencia'],
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.grey.shade100,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const SizedBox(),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Colors.grey.shade400,
                                  size: 24,
                                ),

                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Detalle de actividad con evidencia ──────────────────────────────────────

class _ActivityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> actividad;
  final int projectId;
  final bool readOnly; // ← nuevo parámetro

  const _ActivityDetailScreen({
    required this.actividad,
    required this.projectId,
    this.readOnly = false, // ← valor por defecto
  });

  @override
  State<_ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<_ActivityDetailScreen> {
  static const _baseUrl = ApiConfig.baseUrl;

  final _obsController = TextEditingController();
  final _descController = TextEditingController();
  List<File> _photos = [];
  bool _saving = false;
  String? _errorMessage;
  bool _isEditing =
      false; // ← se agrega esto para controlar si se está editando

  @override
  void initState() {
    super.initState();
    _descController.text = widget.actividad['descripcion'] ?? '';
  }

  @override
  void dispose() {
    _descController.dispose();
    _obsController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (_photos.isEmpty && _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega una foto o descripción de evidencia'),
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
      final actId = widget.actividad['id'];

      final uri = Uri.parse(
        '$_baseUrl/api/cronograma-actividades/$actId/completar',
      );

      final request = http.MultipartRequest('PATCH', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Descripción y observaciones
      request.fields['descripcionEvidencia'] = _descController.text.trim();
      request.fields['observaciones'] = _obsController.text.trim();

      /* Foto principal (solo la primera)
      if (_photos.isNotEmpty) {
        /*final file = await http.MultipartFile.fromPath(
          'file',
          _photos[0].path,
          contentType: MediaType('image', 'jpeg'),
        );*/
        final file = await http.MultipartFile.fromPath('file', _photos[0].path,
            contentType: MediaType('image', 'jpeg'));
        request.files.add(file);
      }*/

      // Enviar todas las fotos
      if (_photos.isNotEmpty) {
        for (final photo in _photos) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'files', // Debe coincidir con @RequestPart("files")
              photo.path,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        }
      }

      debugPrint(
        '>>> Archivo enviado: ${request.files.isNotEmpty ? request.files[0].filename : "NINGUNO"}',
      );
      debugPrint('>>> Fields: ${request.fields}');

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      debugPrint('>>> Status completar: ${response.statusCode}');
      debugPrint('>>> Body completar: ${response.body}');

      if (!mounted) return;
      setState(() => _saving = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Actividad completada con evidencia'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['message'] ?? 'Error al guardar');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Error de conexión: $e';
        });
      }
    }
  }

  /*Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      final actId = widget.actividad['id'];

      // Convertir fotos a Base64
      List<Map<String, dynamic>> evidencias = [];
      for (int i = 0; i < _photos.length; i++) {
        final bytes = await _photos[i].readAsBytes();
        evidencias.add({
          'archivoBase64': base64Encode(bytes),
          'tipoArchivo': 'imagen',
          'mimeType': 'image/jpeg',
          'esPrincipal': i == 0,
          'tamanoArchivo': bytes.length,
          'descripcion': 'Evidencia actividad ${i + 1}',
        });
      }

      final body = jsonEncode({
        ...widget.actividad,
        'descripcion': _descController.text.trim(),
        'evidencias': evidencias,
      });

      final response = await http.put(
        Uri.parse('$_baseUrl/api/cronograma-actividades/$actId'),
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
              content: Text('Evidencia guardada exitosamente'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage =
            data['message'] ?? 'Error al guardar');
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

  /*Widget build(BuildContext context) {
    final act = widget.actividad;
    final nombre = act['nombre'] ?? act['actividad'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cronograma',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
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
                color: Colors.green,
                size: 28,
              ),
              onPressed: _save,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Nombre actividad ─────────────────────────
            Text(
              nombre,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            // ── Fechas ───────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  '${act['fechaInicio'] ?? ''} → ${act['fechaFin'] ?? ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Descripción / avance ─────────────────────
            const Text(
              'Descripción / avance',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe el avance de esta actividad...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Evidencia fotográfica ────────────────────
            const Text(
              'Evidencia fotográfica',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 16),
            const Text(
              'Observaciones',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _obsController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ej: Actividad completada exitosamente...',
                border: OutlineInputBorder(),
              ),
            ),

            // Grid de fotos
            if (_photos.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _photos.length,
                itemBuilder: (_, i) => Stack(
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
                        onTap: () => setState(() => _photos.removeAt(i)),
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
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Principal',
                            style: TextStyle(color: Colors.white, fontSize: 9),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Botón agregar foto
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.grey.shade600,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _photos.isEmpty
                          ? 'Agregar evidencia fotográfica'
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

            // ── Error ────────────────────────────────────
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
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
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }*/
  @override
  Widget build(BuildContext context) {
    final act = widget.actividad;
    final nombre = act['nombre'] ?? act['actividad'] ?? '';
    final readOnly = widget.readOnly;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cronograma',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          if (readOnly && !_isEditing) ...[
            // Botón editar cuando está completada
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Editar',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text(
                  'Completada',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: Colors.green.shade600,
                padding: EdgeInsets.zero,
              ),
            ),
          ] else if (_isEditing || !readOnly) ...[
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              // Cancelar edición
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() {
                    _isEditing = false;
                    _photos = [];
                    _descController.text =
                        widget.actividad['descripcion'] ?? '';
                    _obsController.text = '';
                  }),
                ),
              // Guardar
              IconButton(
                icon: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 28,
                ),
                onPressed: _save,
              ),
            ],
          ],
        ],
        /*actions: [
          // Solo mostrar botón guardar si NO es readOnly
          if (!readOnly)
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
                  color: Colors.green,
                  size: 28,
                ),
                onPressed: _save,
              )
          else
            // Badge de completada
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text(
                  'Completada',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: Colors.green.shade600,
                padding: EdgeInsets.zero,
              ),
            ),
        ],*/
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Nombre actividad ─────────────────────────
            Text(
              nombre,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            // ── Fechas ───────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  '${act['fechaInicio'] ?? ''} → ${act['fechaFin'] ?? ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Descripción ──────────────────────────────
            const Text(
              'Descripción / avance',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 8),

            (readOnly && !_isEditing)
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      act['descripcion'] ?? 'Sin descripción',
                      style: const TextStyle(fontSize: 14),
                    ),
                  )
                : TextField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Describe el avance de esta actividad...',
                      border: OutlineInputBorder(),
                    ),
                  ),
            /*readOnly
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      act['descripcion'] ?? 'Sin descripción',
                      style: const TextStyle(fontSize: 14),
                    ),
                  )
                : TextField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Describe el avance de esta actividad...',
                      border: OutlineInputBorder(),
                    ),
                  ),*/
            const SizedBox(height: 20),

            // ── Observaciones ─────────────────────────────
            const Text(
              'Observaciones',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 8),
            (readOnly && !_isEditing)
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      act['observaciones'] ?? 'Sin observaciones',
                      style: const TextStyle(fontSize: 14),
                    ),
                  )
                : TextField(
                    controller: _obsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Ej: Actividad completada exitosamente...',
                      border: OutlineInputBorder(),
                    ),
                  ),
            /*readOnly
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      act['observaciones'] ?? 'Sin observaciones',
                      style: const TextStyle(fontSize: 14),
                    ),
                  )
                : TextField(
                    controller: _obsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Ej: Actividad completada exitosamente...',
                      border: OutlineInputBorder(),
                    ),
                  ),*/
            const SizedBox(height: 20),

            // ── Evidencia fotográfica ────────────────────
            const Text(
              'Evidencia fotográfica',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 8),

            // Mostrar foto existente si tiene
            if (readOnly && !_isEditing) ...[
              if (act['urlEvidencia'] != null &&
                  act['urlEvidencia'].toString().isNotEmpty)
                // Mostrar por URL
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: act['urlEvidencia'],
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
                  ),
                )
              else if (act['evidencias'] != null &&
                  (act['evidencias'] as List).isNotEmpty &&
                  act['evidencias'][0]['archivoBase64'] != null)
                // Mostrar desde Base64
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(
                      act['evidencias'][0]['archivoBase64'].toString(),
                    ),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        color: Colors.grey.shade400,
                        size: 32,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sin evidencia fotográfica',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              // Modo edición: grid de fotos nuevas
              if (_photos.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (_, i) => Stack(
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
                          onTap: () => setState(() => _photos.removeAt(i)),
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
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(6),
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

              // Botón agregar foto
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.grey.shade600,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _photos.isEmpty
                            ? 'Agregar evidencia fotográfica'
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
            ],

            // ── Error ────────────────────────────────────
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
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
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
