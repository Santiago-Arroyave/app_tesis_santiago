import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/services/supabase_storage_service.dart';

class _EvidenceItem {
  int? id;
  final String? url;
  final File? newFile;
  bool isPrincipal;

  _EvidenceItem({
    this.id,
    this.url,
    this.newFile,
    this.isPrincipal = false,
  });
}

class EditReportScreen extends StatefulWidget {
  final Map<String, dynamic> reporte;

  const EditReportScreen({
    super.key,
    required this.reporte,
  });

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  static const _baseUrl = ApiConfig.baseUrl;

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _sectorController;
  late TextEditingController _descController;

  // Controladores para Datos Específicos según Categoría
  // Flora
  final TextEditingController _floraEspecieController = TextEditingController();
  final TextEditingController _floraCantidadController = TextEditingController();
  final TextEditingController _floraEstadoController = TextEditingController();

  // Fauna
  final TextEditingController _faunaEspecieController = TextEditingController();
  final TextEditingController _faunaIndividuosController = TextEditingController();
  final TextEditingController _faunaComportamientoController = TextEditingController();
  final TextEditingController _faunaEstadoController = TextEditingController();

  // Suelo
  final TextEditingController _sueloTipoHallazgoController = TextEditingController();
  final TextEditingController _sueloCondicionController = TextEditingController();
  final TextEditingController _sueloHumedadController = TextEditingController();
  final TextEditingController _sueloAfectacionController = TextEditingController();

  // Agua
  final TextEditingController _aguaFuenteController = TextEditingController();
  final TextEditingController _aguaNovedadController = TextEditingController();
  final TextEditingController _aguaAfectacionController = TextEditingController();
  final TextEditingController _aguaDescController = TextEditingController();

  // Aire
  final TextEditingController _aireNovedadController = TextEditingController();
  final TextEditingController _aireIntensidadController = TextEditingController();
  final TextEditingController _aireCondicionController = TextEditingController();
  final TextEditingController _aireDireccionController = TextEditingController();

  // Campos adicionales no categorizados
  final Map<String, dynamic> _extraSpecificFields = {};

  final List<_EvidenceItem> _fotos = [];
  final List<int> _evidenciasEliminadasIds = [];
  final List<String> _urlsEliminadasSinId = [];
  bool _isSaving = false;
  String _savingStatusText = '';

  late String _categoryName;

  @override
  void initState() {
    super.initState();
    final r = widget.reporte;

    _categoryName = (r['categoriaNombre'] ?? r['categoria']?['nombre'] ?? 'Flora').toString();

    _sectorController = TextEditingController(
      text: (r['sector'] ?? r['ubicacionTexto'] ?? '').toString(),
    );
    _descController = TextEditingController(
      text: (r['descripcion'] ?? '').toString(),
    );

    _initSpecificData(r['datosEspecificos'] ?? r['specificData']);
    _initEvidences(r);
    _syncEvidencesWithBackend();
  }

  @override
  void dispose() {
    _sectorController.dispose();
    _descController.dispose();

    _floraEspecieController.dispose();
    _floraCantidadController.dispose();
    _floraEstadoController.dispose();

    _faunaEspecieController.dispose();
    _faunaIndividuosController.dispose();
    _faunaComportamientoController.dispose();
    _faunaEstadoController.dispose();

    _sueloTipoHallazgoController.dispose();
    _sueloCondicionController.dispose();
    _sueloHumedadController.dispose();
    _sueloAfectacionController.dispose();

    _aguaFuenteController.dispose();
    _aguaNovedadController.dispose();
    _aguaAfectacionController.dispose();
    _aguaDescController.dispose();

    _aireNovedadController.dispose();
    _aireIntensidadController.dispose();
    _aireCondicionController.dispose();
    _aireDireccionController.dispose();

    super.dispose();
  }

  void _initSpecificData(dynamic raw) {
    Map<String, dynamic> data = {};
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    final catLower = _categoryName.toLowerCase();
    if (catLower.contains('flora')) {
      _floraEspecieController.text = (data['especie'] ?? data['nombreComun'] ?? '').toString();
      _floraCantidadController.text = (data['cantidad'] ?? data['densidad'] ?? '').toString();
      _floraEstadoController.text = (data['estadoVegetal'] ?? data['estado'] ?? '').toString();
    } else if (catLower.contains('fauna') || catLower.contains('animal')) {
      _faunaEspecieController.text = (data['especie'] ?? data['nombreComun'] ?? '').toString();
      _faunaIndividuosController.text = (data['individuos'] ?? data['cantidad'] ?? '').toString();
      _faunaComportamientoController.text = (data['comportamiento'] ?? '').toString();
      _faunaEstadoController.text = (data['estadoAnimal'] ?? data['estado'] ?? '').toString();
    } else if (catLower.contains('suelo') || catLower.contains('tierra')) {
      _sueloTipoHallazgoController.text = (data['tipoHallazgo'] ?? data['hallazgo'] ?? '').toString();
      _sueloCondicionController.text = (data['condicion'] ?? '').toString();
      _sueloHumedadController.text = (data['humedad'] ?? '').toString();
      _sueloAfectacionController.text = (data['afectacion'] ?? '').toString();
    } else if (catLower.contains('agua') || catLower.contains('hídric')) {
      _aguaFuenteController.text = (data['fuenteHidrica'] ?? data['tipoFuente'] ?? data['fuente'] ?? '').toString();
      _aguaNovedadController.text = (data['novedad'] ?? '').toString();
      _aguaAfectacionController.text = (data['afectacion'] ?? '').toString();
      _aguaDescController.text = (data['descripcionEstado'] ?? data['descripcion'] ?? '').toString();
    } else if (catLower.contains('aire') || catLower.contains('clima')) {
      _aireNovedadController.text = (data['novedad'] ?? '').toString();
      _aireIntensidadController.text = (data['intensidad'] ?? '').toString();
      _aireCondicionController.text = (data['condicion'] ?? '').toString();
      _aireDireccionController.text = (data['direccionViento'] ?? data['viento'] ?? '').toString();
    } else {
      // Guardar campos genéricos
      _extraSpecificFields.addAll(data);
    }
  }

  void _initEvidences(Map<String, dynamic> r) {
    final list = <_EvidenceItem>[];
    final Set<String> addedUrls = {};

    // 1. Primero cargar la lista de evidencias con sus IDs reales de la BD
    final rawEvidencias = r['evidencias'];
    if (rawEvidencias is List) {
      for (final ev in rawEvidencias) {
        if (ev is Map) {
          final url = (ev['urlArchivo'] ?? ev['archivoUrl'] ?? ev['url'] ?? ev['fotoUrl'])?.toString().trim();
          if (url != null && url.isNotEmpty) {
            final evId = ev['id'] is num
                ? (ev['id'] as num).toInt()
                : int.tryParse(ev['id']?.toString() ?? '');
            final isPrinc = ev['esPrincipal'] == true || list.isEmpty;
            if (!addedUrls.contains(url)) {
              addedUrls.add(url);
              list.add(_EvidenceItem(
                id: evId,
                url: url,
                isPrincipal: isPrinc,
              ));
            }
          }
        }
      }
    }

    // 2. Foto principal si existe y no estaba ya en la lista de evidencias
    final fotoPrincipal = r['fotoPrincipalUrl'] ?? r['fotoUrl'] ?? r['urlFoto'] ?? r['foto'];
    if (fotoPrincipal != null && fotoPrincipal.toString().trim().isNotEmpty) {
      final url = fotoPrincipal.toString().trim();
      if (!addedUrls.contains(url)) {
        addedUrls.add(url);
        for (final item in list) {
          item.isPrincipal = false;
        }
        list.insert(0, _EvidenceItem(url: url, isPrincipal: true));
      } else {
        for (final item in list) {
          item.isPrincipal = (item.url == url);
        }
      }
    }

    setState(() {
      _fotos
        ..clear()
        ..addAll(list);
    });
  }

  /// Sincroniza los IDs de las evidencias desde el backend (`GET /api/reportes/{id}`)
  /// cuando el mapa entrante provenía de un resumen sin IDs en `evidencias`.
  Future<void> _syncEvidencesWithBackend() async {
    final reportId = widget.reporte['id'];
    if (reportId == null) return;

    final needsSync = _fotos.any((f) => f.id == null && f.url != null) ||
        (widget.reporte['evidencias'] as List?) == null ||
        (widget.reporte['evidencias'] as List).isEmpty;
    if (!needsSync) return;

    try {
      final token = await AuthStorage.getToken();
      final cleanToken = (token ?? '').trim().startsWith('Bearer ')
          ? (token ?? '').trim().substring(7).trim()
          : (token ?? '').trim();

      final res = await http.get(
        Uri.parse('$_baseUrl/api/reportes/$reportId'),
        headers: {
          'Content-Type': 'application/json',
          if (cleanToken.isNotEmpty) 'Authorization': 'Bearer $cleanToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (!mounted || res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      if (data is! Map) return;

      final rawEvs = data['evidencias'];
      if (rawEvs is! List || rawEvs.isEmpty) return;

      setState(() {
        for (final ev in rawEvs) {
          if (ev is! Map) continue;
          final evId = ev['id'] is num
              ? (ev['id'] as num).toInt()
              : int.tryParse(ev['id']?.toString() ?? '');
          final url = (ev['urlArchivo'] ?? ev['archivoUrl'] ?? ev['url'] ?? ev['fotoUrl'])
              ?.toString()
              .trim();
          if (evId == null || url == null || url.isEmpty) continue;

          // Si el usuario ya había tocado la 'X' sobre esta URL antes de que llegara el ID
          if (_urlsEliminadasSinId.contains(url)) {
            if (!_evidenciasEliminadasIds.contains(evId)) {
              _evidenciasEliminadasIds.add(evId);
            }
            continue;
          }

          final matchIdx = _fotos.indexWhere((f) => f.url == url);
          if (matchIdx != -1) {
            _fotos[matchIdx].id = evId;
          } else {
            _fotos.add(_EvidenceItem(
              id: evId,
              url: url,
              isPrincipal: ev['esPrincipal'] == true && !_fotos.any((f) => f.isPrincipal),
            ));
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    final activeCount = _fotos.length;
    if (activeCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Límite de 5 evidencias fotográficas alcanzado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (picked != null) {
        setState(() {
          _fotos.add(
            _EvidenceItem(
              newFile: File(picked.path),
              isPrincipal: activeCount == 0,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar imagen: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddPhotoModal() {
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
              const SizedBox(height: 16),
              Text(
                "Agregar evidencia fotográfica",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2822) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1E5E3A)),
                ),
                title: const Text("Tomar foto con la cámara", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("Captura en campo con coordenadas activas", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2822) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFF1E5E3A)),
                ),
                title: const Text("Elegir de la galería", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("Seleccionar foto existente del dispositivo", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _removeEvidenceAt(int index) {
    if (index < 0 || index >= _fotos.length) return;
    final evidencia = _fotos[index];
    final wasPrincipal = evidencia.isPrincipal;

    setState(() {
      if (evidencia.id != null) {
        if (!_evidenciasEliminadasIds.contains(evidencia.id!)) {
          _evidenciasEliminadasIds.add(evidencia.id!);
        }
      } else if (evidencia.url != null && evidencia.url!.isNotEmpty) {
        _urlsEliminadasSinId.add(evidencia.url!);
      }

      _fotos.removeAt(index);

      // Reasignar principal si se eliminó la foto principal y quedan otras
      if (wasPrincipal && _fotos.isNotEmpty) {
        _fotos.first.isPrincipal = true;
      }
    });
  }

  void _setPrincipalEvidence(_EvidenceItem item) {
    setState(() {
      for (final e in _fotos) {
        e.isPrincipal = (e == item);
      }
    });
  }

  Map<String, dynamic> _collectSpecificData() {
    final catLower = _categoryName.toLowerCase();
    final map = Map<String, dynamic>.from(_extraSpecificFields);

    if (catLower.contains('flora')) {
      if (_floraEspecieController.text.trim().isNotEmpty) {
        map['especie'] = _floraEspecieController.text.trim();
      }
      if (_floraCantidadController.text.trim().isNotEmpty) {
        map['cantidad'] = _floraCantidadController.text.trim();
      }
      if (_floraEstadoController.text.trim().isNotEmpty) {
        map['estadoVegetal'] = _floraEstadoController.text.trim();
      }
    } else if (catLower.contains('fauna') || catLower.contains('animal')) {
      if (_faunaEspecieController.text.trim().isNotEmpty) {
        map['especie'] = _faunaEspecieController.text.trim();
      }
      if (_faunaIndividuosController.text.trim().isNotEmpty) {
        map['individuos'] = _faunaIndividuosController.text.trim();
      }
      if (_faunaComportamientoController.text.trim().isNotEmpty) {
        map['comportamiento'] = _faunaComportamientoController.text.trim();
      }
      if (_faunaEstadoController.text.trim().isNotEmpty) {
        map['estadoAnimal'] = _faunaEstadoController.text.trim();
      }
    } else if (catLower.contains('suelo') || catLower.contains('tierra')) {
      if (_sueloTipoHallazgoController.text.trim().isNotEmpty) {
        map['tipoHallazgo'] = _sueloTipoHallazgoController.text.trim();
      }
      if (_sueloCondicionController.text.trim().isNotEmpty) {
        map['condicion'] = _sueloCondicionController.text.trim();
      }
      if (_sueloHumedadController.text.trim().isNotEmpty) {
        map['humedad'] = _sueloHumedadController.text.trim();
      }
      if (_sueloAfectacionController.text.trim().isNotEmpty) {
        map['afectacion'] = _sueloAfectacionController.text.trim();
      }
    } else if (catLower.contains('agua') || catLower.contains('hídric')) {
      if (_aguaFuenteController.text.trim().isNotEmpty) {
        map['fuenteHidrica'] = _aguaFuenteController.text.trim();
      }
      if (_aguaNovedadController.text.trim().isNotEmpty) {
        map['novedad'] = _aguaNovedadController.text.trim();
      }
      if (_aguaAfectacionController.text.trim().isNotEmpty) {
        map['afectacion'] = _aguaAfectacionController.text.trim();
      }
      if (_aguaDescController.text.trim().isNotEmpty) {
        map['descripcionEstado'] = _aguaDescController.text.trim();
      }
    } else if (catLower.contains('aire') || catLower.contains('clima')) {
      if (_aireNovedadController.text.trim().isNotEmpty) {
        map['novedad'] = _aireNovedadController.text.trim();
      }
      if (_aireIntensidadController.text.trim().isNotEmpty) {
        map['intensidad'] = _aireIntensidadController.text.trim();
      }
      if (_aireCondicionController.text.trim().isNotEmpty) {
        map['condicion'] = _aireCondicionController.text.trim();
      }
      if (_aireDireccionController.text.trim().isNotEmpty) {
        map['direccionViento'] = _aireDireccionController.text.trim();
      }
    }

    return map;
  }

  Future<void> _saveChanges() => _guardarCambios();

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final reportId = widget.reporte['id'];
    if (reportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el ID del reporte para actualizar'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatusText = 'Procesando evidencias fotográficas...';
    });

    try {
      final token = await AuthStorage.getToken();
      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión no encontrada o expirada. Por favor inicia sesión nuevamente.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final cleanToken = token.trim().startsWith('Bearer ')
          ? token.trim().substring(7).trim()
          : token.trim();

      // Si alguna foto existente fue eliminada antes de tener su ID, resolverlo
      if (_urlsEliminadasSinId.isNotEmpty) {
        await _syncEvidencesWithBackend();
      }

      final List<Map<String, dynamic>> evidenciasPayload = [];
      String? updatedFotoPrincipalUrl;

      // 1. Evidencias conservadas existentes
      for (final ev in _fotos.where((e) => e.id != null)) {
        evidenciasPayload.add({
          'id': ev.id,
          'urlArchivo': ev.url,
          'tipoArchivo': 'imagen',
          'esPrincipal': ev.isPrincipal,
        });
        if (ev.isPrincipal && ev.url != null) {
          updatedFotoPrincipalUrl = ev.url;
        }
      }

      // 2. Subir nuevas fotos a Supabase Storage bucket goblin-media
      final newPhotos = _fotos.where((e) => e.newFile != null).toList();
      for (int i = 0; i < newPhotos.length; i++) {
        final ev = newPhotos[i];
        if (!mounted) return;
        setState(() {
          _savingStatusText = 'Subiendo foto ${i + 1} de ${newPhotos.length} a Supabase...';
        });

        final publicUrl = await SupabaseStorageService.uploadReportImage(ev.newFile!);
        if (publicUrl != null) {
          final fileName = ev.newFile!.path.split(Platform.isWindows ? '\\' : '/').last;
          evidenciasPayload.add({
            'urlArchivo': publicUrl,
            'tipoArchivo': 'imagen',
            'nombreArchivo': fileName,
            'mimeType': 'image/jpeg',
            'esPrincipal': ev.isPrincipal,
          });
          if (ev.isPrincipal) {
            updatedFotoPrincipalUrl = publicUrl;
          }
        } else {
          debugPrint('Advertencia: No se pudo subir una de las fotos a Supabase');
        }
      }

      // 3. Agregar evidencias eliminadas con el flag "eliminar": true
      for (final idEliminado in _evidenciasEliminadasIds) {
        evidenciasPayload.add({
          'id': idEliminado,
          'eliminar': true,
          'tipoArchivo': 'imagen',
        });
      }

      // Si no hay foto principal explícita pero hay activas, tomar la primera
      if (updatedFotoPrincipalUrl == null && _fotos.isNotEmpty) {
        final firstActive = _fotos.firstWhere(
          (e) => e.url != null,
          orElse: () => _EvidenceItem(),
        );
        if (firstActive.url != null) {
          updatedFotoPrincipalUrl = firstActive.url;
        }
      }

      if (!mounted) return;
      setState(() {
        _savingStatusText = 'Guardando cambios en el servidor...';
      });

      // Construcción del JSON de ReporteUpdateRequest
      final specificData = _collectSpecificData();
      final Map<String, dynamic> updateBody = {
        if (widget.reporte['titulo'] != null &&
            widget.reporte['titulo'].toString().trim().isNotEmpty)
          'titulo': widget.reporte['titulo'].toString().trim(),
        'sector': _sectorController.text.trim(),
        'descripcion': _descController.text.trim(),
        'datosEspecificos': specificData,
        'evidencias': evidenciasPayload,
      };

      if (updatedFotoPrincipalUrl != null && updatedFotoPrincipalUrl.isNotEmpty) {
        updateBody['fotoPrincipalUrl'] = updatedFotoPrincipalUrl;
      } else if (_fotos.isEmpty) {
        updateBody['fotoPrincipalUrl'] = null;
      }

      final res = await http.put(
        Uri.parse('$_baseUrl/api/reportes/$reportId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cleanToken',
        },
        body: jsonEncode(updateBody),
      ).timeout(const Duration(seconds: 25));

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (res.statusCode == 200 || res.statusCode == 201) {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(res.body);
        } catch (_) {
          responseData = Map<String, dynamic>.from(widget.reporte);
          responseData['sector'] = _sectorController.text.trim();
          responseData['descripcion'] = _descController.text.trim();
          responseData['datosEspecificos'] = specificData;
          responseData['fotoPrincipalUrl'] = updatedFotoPrincipalUrl;
          responseData['evidencias'] = evidenciasPayload
              .where((e) => e['eliminar'] != true)
              .toList();
        }

        Navigator.pop(context, responseData);
      } else {
        String errMsg = 'Error al actualizar el reporte (HTTP ${res.statusCode})';
        try {
          final errBody = jsonDecode(res.body);
          if (errBody is Map) {
            if (errBody['message'] != null &&
                errBody['message'].toString().trim().isNotEmpty) {
              errMsg = errBody['message'].toString();
            } else if (errBody['error'] != null &&
                errBody['error'].toString().trim().isNotEmpty) {
              errMsg = '${errBody['error']} (HTTP ${res.statusCode})';
            }
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al guardar reporte: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeEvidences = _fotos;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Editar reporte",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E5E3A)),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check, color: Color(0xFF1E5E3A), size: 19),
              label: const Text(
                "Guardar",
                style: TextStyle(
                  color: Color(0xFF1E5E3A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                // 1. Tarjeta informativa de categoría
                _buildCategoryBanner(theme, isDark),
                const SizedBox(height: 16),

                // 2. Información General: Sector y Descripción
                _buildGeneralInfoSection(theme, isDark),
                const SizedBox(height: 20),

                // 3. Datos Específicos Técnicos según Categoría
                _buildCategorySpecificSection(theme, isDark),
                const SizedBox(height: 20),

                // 4. Galería de Evidencias Fotográficas
                _buildEvidencesGallerySection(theme, isDark, activeEvidences),
              ],
            ),
          ),

          // Overlay de guardado / subida
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E5E3A)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _savingStatusText.isNotEmpty ? _savingStatusText : 'Guardando cambios...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveChanges,
            icon: const Icon(Icons.save_outlined, color: Colors.white, size: 20),
            label: const Text(
              "Guardar Cambios",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5E3A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECCIÓN 1: BANNER DE CATEGORÍA
  // ===========================================================================
  Widget _buildCategoryBanner(ThemeData theme, bool isDark) {
    Color catColor = const Color(0xFF1E5E3A);
    IconData catIcon = Icons.eco;
    final catLower = _categoryName.toLowerCase();
    if (catLower.contains('fauna') || catLower.contains('animal')) {
      catColor = const Color(0xFF9A6735);
      catIcon = Icons.pets;
    } else if (catLower.contains('suelo') || catLower.contains('tierra')) {
      catColor = const Color(0xFF8C5E48);
      catIcon = Icons.landscape;
    } else if (catLower.contains('agua') || catLower.contains('hídric')) {
      catColor = const Color(0xFF2563EB);
      catIcon = Icons.water_drop;
    } else if (catLower.contains('aire') || catLower.contains('clima')) {
      catColor = const Color(0xFF0284C7);
      catIcon = Icons.air;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: catColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(catIcon, color: catColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Categoría: $_categoryName",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: catColor,
                  ),
                ),
                Text(
                  "Edición de parámetros y evidencias de observación",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECCIÓN 2: INFORMACIÓN GENERAL (SECTOR Y DESCRIPCIÓN)
  // ===========================================================================
  Widget _buildGeneralInfoSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Color(0xFF1E5E3A), size: 18),
              const SizedBox(width: 8),
              Text(
                "Ubicación y Detalle",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Campo Sector
          Text(
            "Sector o punto de referencia *",
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _sectorController,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'El sector es obligatorio' : null,
            decoration: InputDecoration(
              hintText: "Ej. Laguna Verde, Sendero El Duende",
              prefixIcon: const Icon(Icons.place_outlined, size: 18),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2620) : const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFD1D5DB),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Campo Descripción
          Text(
            "Descripción de la observación *",
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descController,
            maxLines: 4,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'La descripción es obligatoria' : null,
            decoration: InputDecoration(
              hintText: "Detalla lo observado en campo...",
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2620) : const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFD1D5DB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECCIÓN 3: CAMPOS TÉCNICOS ESPECÍFICOS SEGÚN CATEGORÍA
  // ===========================================================================
  Widget _buildCategorySpecificSection(ThemeData theme, bool isDark) {
    final catLower = _categoryName.toLowerCase();

    List<Widget> fieldWidgets = [];

    if (catLower.contains('flora')) {
      fieldWidgets = [
        _buildTextField(
          controller: _floraEspecieController,
          label: "Especie o nombre común",
          hint: "Ej. Frailejón, Encenillo, Chusque",
          icon: Icons.eco_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _floraCantidadController,
          label: "Cantidad o densidad estimada",
          hint: "Ej. 10 ejemplares, parche denso",
          icon: Icons.numbers_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _floraEstadoController,
          label: "Estado vegetal / fenológico",
          hint: "Ej. En floración, saludable, seco",
          icon: Icons.local_florist_outlined,
          isDark: isDark,
        ),
      ];
    } else if (catLower.contains('fauna') || catLower.contains('animal')) {
      fieldWidgets = [
        _buildTextField(
          controller: _faunaEspecieController,
          label: "Especie o nombre común",
          hint: "Ej. Oso de anteojos, Pava andina, Huellas",
          icon: Icons.pets_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _faunaIndividuosController,
          label: "Número de individuos",
          hint: "Ej. 2 adultos, 1 juvenil",
          icon: Icons.format_list_numbered_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _faunaComportamientoController,
          label: "Comportamiento observado",
          hint: "Ej. Alimentación, desplazamiento, reposo",
          icon: Icons.visibility_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _faunaEstadoController,
          label: "Estado del animal",
          hint: "Ej. Activo y saludable, herido",
          icon: Icons.health_and_safety_outlined,
          isDark: isDark,
        ),
      ];
    } else if (catLower.contains('suelo') || catLower.contains('tierra')) {
      fieldWidgets = [
        _buildTextField(
          controller: _sueloTipoHallazgoController,
          label: "Tipo de hallazgo / sustrato",
          hint: "Ej. Erosión, turbera, deslizamiento",
          icon: Icons.landscape_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _sueloCondicionController,
          label: "Condición del terreno",
          hint: "Ej. Firme, saturado, degradado",
          icon: Icons.terrain_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _sueloHumedadController,
          label: "Nivel de humedad",
          hint: "Ej. Alta, moderada, seco",
          icon: Icons.water_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _sueloAfectacionController,
          label: "Nivel de afectación",
          hint: "Ej. Natural, paso de ganado, quema",
          icon: Icons.warning_amber_outlined,
          isDark: isDark,
        ),
      ];
    } else if (catLower.contains('agua') || catLower.contains('hídric')) {
      fieldWidgets = [
        _buildTextField(
          controller: _aguaFuenteController,
          label: "Fuente hídrica",
          hint: "Ej. Quebrada La Cristalina, Laguna Verde",
          icon: Icons.water_drop_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aguaNovedadController,
          label: "Novedad en el cauce",
          hint: "Ej. Disminución de caudal, turbidez",
          icon: Icons.waves_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aguaAfectacionController,
          label: "Nivel de afectación / contaminación",
          hint: "Ej. Ninguna, residuos, turbidez alta",
          icon: Icons.science_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aguaDescController,
          label: "Descripción de calidad de agua",
          hint: "Ej. Transparente, sin olor",
          icon: Icons.info_outline,
          isDark: isDark,
        ),
      ];
    } else if (catLower.contains('aire') || catLower.contains('clima')) {
      fieldWidgets = [
        _buildTextField(
          controller: _aireNovedadController,
          label: "Novedad atmosférica",
          hint: "Ej. Humo visible, neblina densa, olor",
          icon: Icons.air_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aireIntensidadController,
          label: "Intensidad",
          hint: "Ej. Alta, media, leve",
          icon: Icons.speed_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aireCondicionController,
          label: "Condición climática",
          hint: "Ej. Nublado, frío intenso, llovizna",
          icon: Icons.cloud_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aireDireccionController,
          label: "Dirección del viento",
          hint: "Ej. Norte a sur, viento en calma",
          icon: Icons.navigation_outlined,
          isDark: isDark,
        ),
      ];
    }

    if (fieldWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_outlined, color: Color(0xFF1E5E3A), size: 18),
              const SizedBox(width: 8),
              Text(
                "Datos Técnicos de $_categoryName",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...fieldWidgets,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
            filled: true,
            fillColor: isDark ? const Color(0xFF1A2620) : const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFD1D5DB),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECCIÓN 4: GALERÍA DE EVIDENCIAS FOTOGRÁFICAS
  // ===========================================================================
  Widget _buildEvidencesGallerySection(
    ThemeData theme,
    bool isDark,
    List<_EvidenceItem> activeEvidences,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_library_outlined, color: Color(0xFF1E5E3A), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Evidencias Fotográficas (${activeEvidences.length}/5)",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              if (activeEvidences.length < 5)
                InkWell(
                  onTap: _showAddPhotoModal,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF1E5E3A), size: 18),
                        SizedBox(width: 4),
                        Text(
                          "Añadir",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E5E3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),

          if (activeEvidences.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      "No hay evidencias fotográficas cargadas",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _showAddPhotoModal,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: const Text("Agregar foto"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E5E3A),
                        side: const BorderSide(color: Color(0xFF1E5E3A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemCount: activeEvidences.length,
              itemBuilder: (ctx, index) {
                final item = activeEvidences[index];
                return _buildEvidenceCard(item, index, theme, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard(
    _EvidenceItem item,
    int index,
    ThemeData theme,
    bool isDark,
  ) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isPrincipal
                  ? const Color(0xFF1E5E3A)
                  : (isDark ? const Color(0x33FFFFFF) : const Color(0xFFE5E7EB)),
              width: item.isPrincipal ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox.expand(
              child: item.newFile != null
                  ? Image.file(item.newFile!, fit: BoxFit.cover)
                  : (item.url != null && item.url!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.url!,
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                        )
                      : Container(color: Colors.grey.shade300)),
            ),
          ),
        ),

        // Badge Foto Principal
        if (item.isPrincipal)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E5E3A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 10),
                  SizedBox(width: 3),
                  Text(
                    "Principal",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Positioned(
            top: 6,
            left: 6,
            child: InkWell(
              onTap: () => _setPrincipalEvidence(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Hacer principal",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

        // Botón Eliminar Foto
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _removeEvidenceAt(index),
              child: const Padding(
                padding: EdgeInsets.all(5.0),
                child: Icon(Icons.close, color: Colors.white, size: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
