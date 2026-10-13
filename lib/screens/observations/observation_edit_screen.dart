import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';

class ObservationEditScreen extends StatefulWidget {
  final Map<String, dynamic> obs;

  const ObservationEditScreen({super.key, required this.obs});

  @override
  State<ObservationEditScreen> createState() => _ObservationEditScreenState();
}

class _ObservationEditScreenState extends State<ObservationEditScreen> {
  static const _baseUrl = ApiConfig.baseUrl;

  late TextEditingController _tituloController;
  late TextEditingController _descController;
  List<Map<String, dynamic>> _existingPhotos = [];
  final List<File> _newPhotos = [];
  bool _saving = false;
  String? _errorMessage;

  /*@override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.obs['titulo'] ?? '');
    _descController = TextEditingController(
      text: widget.obs['descripcion'] ?? '',
    );
  }*/

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.obs['titulo'] ?? '');
    _descController = TextEditingController(
      text: widget.obs['descripcion'] ?? '',
    );
    // Cargar fotos existentes
    final evidencias = (widget.obs['evidencias'] as List?) ?? [];
    _existingPhotos = evidencias
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ── Seleccionar foto ───────────────────────────────────
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
        setState(() => _newPhotos.add(File(picked.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Guardar cambios ────────────────────────────────────

  Future<void> _save() async {
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título no puede estar vacío')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthStorage.getToken();
      final cleanToken = (token ?? '').trim().startsWith('Bearer ')
          ? (token ?? '').trim().substring(7).trim()
          : (token ?? '').trim();
      final id = widget.obs['id'];

      // ── 1. PUT incluyendo evidencias existentes ───────────
      final Map<String, dynamic> bodyMap = {
        'id': widget.obs['id'],
        'usuarioId': widget.obs['usuarioId'],
        'categoriaId': widget.obs['categoriaId'],
        'prioridadId': widget.obs['prioridadId'],
        'estadoReporteId': widget.obs['estadoReporteId'],
        'titulo': _tituloController.text.trim(),
        'descripcion': _descController.text.trim(),
        'fechaEvento': widget.obs['fechaEvento'],
        'fuente': widget.obs['fuente'],
        'latitud': widget.obs['latitud'],
        'longitud': widget.obs['longitud'],
        'direccionReferencia': widget.obs['direccionReferencia'],
        'fotoPrincipalUrl': widget.obs['fotoPrincipalUrl'],
        'publico': widget.obs['publico'],
        'estado': widget.obs['estado'],
        'evidencias': widget.obs['evidencias'] ?? [],
        'comentarios': widget.obs['comentarios'] ?? [],
      };

      final response = await http.put(
        Uri.parse('$_baseUrl/api/reportes/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cleanToken',
        },
        body: jsonEncode(bodyMap),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _saving = false;
          _errorMessage = data['message'] ?? 'Error al actualizar';
        });
        return;
      }

      // ── 2. POST fotos nuevas por separado ─────────────────
      for (int i = 0; i < _newPhotos.length; i++) {
        final bytes = await _newPhotos[i].readAsBytes();
        final nombreArchivo =
            'foto_obs_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await http.post(
          Uri.parse('$_baseUrl/api/evidencias'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'idReporte': id,
            'archivoBase64': base64Encode(bytes),
            'tipoArchivo': 'imagen',
            'nombreArchivo': nombreArchivo,
            'mimeType': 'image/jpeg',
            'esPrincipal': i == 0,
            'tamanoArchivo': bytes.length,
            'descripcion': 'Foto ${i + 1}',
            'storageProvider': 'local',
          }),
        );
      }

      if (!mounted) return;
      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observación actualizada'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
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
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título no puede estar vacío')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      final id = widget.obs['id'];

      // Convertir fotos nuevas a Base64
      List<Map<String, dynamic>> evidencias = [];
      for (int i = 0; i < _newPhotos.length; i++) {
        final bytes = await _newPhotos[i].readAsBytes();
        final nombreArchivo =
            'foto_obs_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        evidencias.add({
          'archivoBase64': base64Encode(bytes),
          'tipoArchivo': 'imagen',
          'nombreArchivo': nombreArchivo,
          'mimeType': 'image/jpeg',
          'esPrincipal': i == 0,
          'tamanoArchivo': bytes.length,
          'descripcion': 'Foto ${i + 1}',
          'storageProvider': 'local',
        });
      }
      /*for (int i = 0; i < _newPhotos.length; i++) {
        final bytes = await _newPhotos[i].readAsBytes();
        evidencias.add({
          'archivoBase64': base64Encode(bytes),
          'tipoArchivo': 'imagen',
          'mimeType': 'image/jpeg',
          'esPrincipal': i == 0,
          'tamanoArchivo': bytes.length,
          'descripcion': 'Foto ${i + 1}',
        });
      }*/

      final body = jsonEncode({
        ...widget.obs,
        'titulo': _tituloController.text.trim(),
        'descripcion': _descController.text.trim(),
        if (evidencias.isNotEmpty) 'evidencias': evidencias,
      });

      final response = await http.put(
        Uri.parse('$_baseUrl/api/reportes/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (!mounted) return;
      setState(() => _saving = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observación actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        setState(
          () => _errorMessage = data['message'] ?? 'Error al actualizar',
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

  // ── Diálogo de descarte ────────────────────────────────
  Future<void> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red.shade600, size: 56),
            const SizedBox(height: 12),
            const Text(
              '¿Descartar cambios?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _confirmDiscard,
          ),
          title: const Text('Editar Observación'),
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
              // ── Categoría ────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.green.shade50,
                    child: Icon(
                      Icons.eco,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.obs['categoriaNombre'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // ── Título ───────────────────────────────────
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Tipo de animal / especie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Descripción ──────────────────────────────
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // ── Fotos nuevas ─────────────────────────────
              /*const Text(
                'Agregar fotos',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const SizedBox(height: 8),

              if (_newPhotos.isNotEmpty) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _newPhotos.length,
                  itemBuilder: (_, i) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_newPhotos[i], fit: BoxFit.cover),
                      ),
                      // Botón eliminar foto
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _newPhotos.removeAt(i)),
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
                      // Badge principal
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
              ],

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
                        _newPhotos.isEmpty
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
              ),*/

              // ── Fotos existentes ─────────────────────────────
              if (_existingPhotos.isNotEmpty) ...[
                const Text(
                  'Fotos actuales',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _existingPhotos.length,
                  itemBuilder: (_, i) {
                    final ev = _existingPhotos[i];
                    final urlArchivo = ev['urlArchivo']?.toString() ??
                        ev['archivoUrl']?.toString() ??
                        ev['url']?.toString() ??
                        '';
                    final base64Str = ev['archivoBase64']?.toString() ?? '';
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: urlArchivo.isNotEmpty &&
                              (urlArchivo.startsWith('http://') ||
                                  urlArchivo.startsWith('https://'))
                          ? CachedNetworkImage(
                              imageUrl: urlArchivo,
                              fit: BoxFit.cover,
                              memCacheWidth: 600,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            )
                          : base64Str.isNotEmpty
                              ? Image.memory(
                                  base64Decode(base64Str),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ── Fotos nuevas ─────────────────────────────────
              const Text(
                'Agregar fotos',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const SizedBox(height: 8),

              if (_newPhotos.isNotEmpty) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _newPhotos.length,
                  itemBuilder: (_, i) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_newPhotos[i], fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _newPhotos.removeAt(i)),
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
                              'Nueva',
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
              ],

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
                        _newPhotos.isEmpty
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
                          style: TextStyle(color: Colors.red.shade700),
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
      ),
    );
  }
}

/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app_tesis/screens/login_screen/auth_service.dart';

class ObservationEditScreen extends StatefulWidget {
  final Map<String, dynamic> obs;

  const ObservationEditScreen({super.key, required this.obs});

  @override
  State<ObservationEditScreen> createState() =>
      _ObservationEditScreenState();
}

class _ObservationEditScreenState extends State<ObservationEditScreen> {
  static const _baseUrl = ApiConfig.baseUrl;

  late TextEditingController _tituloController;
  late TextEditingController _descController;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tituloController =
        TextEditingController(text: widget.obs['titulo'] ?? '');
    _descController =
        TextEditingController(text: widget.obs['descripcion'] ?? '');
  }

  Future<void> _save() async {
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título no puede estar vacío')),
      );
      return;
    }

    // Diálogo de confirmación de descarte si cancela
    setState(() { _saving = true; _errorMessage = null; });

    try {
      final token = await AuthService.getToken();
      final id = widget.obs['id'];

      final body = jsonEncode({
        ...widget.obs,
        'titulo': _tituloController.text.trim(),
        'descripcion': _descController.text.trim(),
      });

      final response = await http.put(
        Uri.parse('$_baseUrl/api/reportes/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (!mounted) return;
      setState(() => _saving = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Observación actualizada'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        setState(() =>
            _errorMessage = data['message'] ?? 'Error al actualizar');
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

  Future<void> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded,
                color: Colors.red.shade600, size: 56),
            const SizedBox(height: 12),
            const Text(
              '¿Descartar cambios?',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _confirmDiscard,
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
                icon: const Icon(Icons.check_circle,
                    color: Colors.green, size: 28),
                onPressed: _save,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categoría
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.green.shade50,
                    child: Icon(Icons.eco,
                        color: Colors.green.shade700, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.obs['categoriaNombre'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Título
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Tipo de animal / especie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),

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
            ],
          ),
        ),
      ),
    );
  }
}*/
