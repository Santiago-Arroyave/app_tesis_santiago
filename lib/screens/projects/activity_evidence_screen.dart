import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';

class ActivityEvidenceScreen extends StatefulWidget {
  final Map<String, dynamic> actividad;
  final String projectName;
  final int projectId;

  const ActivityEvidenceScreen({
    super.key,
    required this.actividad,
    required this.projectName,
    required this.projectId,
  });

  @override
  State<ActivityEvidenceScreen> createState() => _ActivityEvidenceScreenState();
}

class _ActivityEvidenceScreenState extends State<ActivityEvidenceScreen> {
  final TextEditingController _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  late Map<String, dynamic> _actividadData;
  List<dynamic> _existingEvidences = [];
  bool _isSaving = false;
  bool _isLoadingEvidences = false;
  String _estado = 'En desarrollo';
  bool _puedeGestionar = false;
  String? _currentUserName;

  String get _responsableNombre {
    final raw = _actividadData['responsableNombre'] ??
        _actividadData['usuarioResponsableNombre'] ??
        _actividadData['nombreResponsable'] ??
        (_actividadData['responsable'] is Map
            ? (_actividadData['responsable']['nombre'] ??
                _actividadData['responsable']['nombres'] ??
                _actividadData['responsable']['usuarioNombre'])
            : null) ??
        widget.actividad['responsableNombre'] ??
        widget.actividad['usuarioResponsableNombre'];
    if (raw != null && raw.toString().trim().isNotEmpty) {
      return raw.toString().trim();
    }
    return 'Sin asignar';
  }

  dynamic get _responsableId {
    return _actividadData['responsableId'] ??
        _actividadData['usuarioResponsableId'] ??
        (_actividadData['responsable'] is Map
            ? _actividadData['responsable']['id']
            : null) ??
        widget.actividad['responsableId'] ??
        widget.actividad['usuarioResponsableId'];
  }

  @override
  void initState() {
    super.initState();
    _actividadData = Map<String, dynamic>.from(widget.actividad);
    _estado = _actividadData['estado']?.toString() ??
        _actividadData['estadoActividad']?.toString() ??
        'En desarrollo';

    _existingEvidences = _extractAllEvidences(_actividadData);

    _checkPermissions();
    _fetchActivityEvidences();
  }

  List<Map<String, dynamic>> _extractAllEvidences(
    Map<String, dynamic> actData, {
    List<dynamic>? extraEvidences,
    List<dynamic>? localBackup,
  }) {
    final List<Map<String, dynamic>> result = [];
    final Set<String> seenKeys = {};

    final String defaultAuthor = _responsableNombre != 'Sin asignar'
        ? _responsableNombre
        : 'Guardabosques';
    final String defaultDate = (actData['updatedAt'] ??
            actData['fechaActualizacion'] ??
            actData['createdAt'] ??
            actData['fechaCreacion'] ??
            actData['fechaFin'] ??
            DateTime.now().toIso8601String())
        .toString();
    final String actObs = (actData['observaciones'] ??
            actData['descripcionEvidencia'] ??
            actData['descripcion'] ??
            'Evidencia registrada en campo')
        .toString()
        .trim();

    void addNormalizedMap(Map rawMap) {
      final map = Map<String, dynamic>.from(rawMap);
      final String url = (map['url'] ??
              map['urlArchivo'] ??
              map['urlEvidencia'] ??
              map['archivoUrl'] ??
              '')
          .toString()
          .trim();
      final String localPath = (map['localPath'] ?? '').toString().trim();
      final String base64Str = (map['archivoBase64'] ?? '').toString().trim();
      final String idStr = (map['id'] ?? '').toString().trim();

      final String dedupKey = idStr.isNotEmpty
          ? 'id:$idStr'
          : (url.isNotEmpty
              ? 'url:$url'
              : (localPath.isNotEmpty
                  ? 'local:$localPath'
                  : (base64Str.isNotEmpty
                      ? 'b64:${base64Str.hashCode}'
                      : 'idx:${result.length}')));

      if (seenKeys.contains(dedupKey)) return;
      seenKeys.add(dedupKey);

      final String rawAutor =
          (map['usuarioNombre'] ?? map['autor'] ?? '').toString().trim();
      final String finalAutor = (rawAutor.isNotEmpty &&
              rawAutor.toLowerCase() != 'null' &&
              rawAutor.toLowerCase() != 'guardabosques')
          ? rawAutor
          : defaultAuthor;

      final String rawDesc =
          (map['descripcion'] ?? map['descripcionEvidencia'] ?? '')
              .toString()
              .trim();
      final String finalDesc = (rawDesc.isNotEmpty &&
              rawDesc.toLowerCase() != 'null')
          ? rawDesc
          : (actObs.isNotEmpty ? actObs : 'Evidencia registrada en campo');

      final String rawFecha = (map['fechaCarga'] ??
              map['fechaCreacion'] ??
              map['createdAt'] ??
              map['fechaSubida'] ??
              map['fecha'] ??
              '')
          .toString()
          .trim();
      final String finalFecha = (rawFecha.isNotEmpty &&
              rawFecha.toLowerCase() != 'null' &&
              rawFecha.toLowerCase() != 'reciente' &&
              rawFecha.toLowerCase() != 'hoy')
          ? rawFecha
          : defaultDate;

      result.add({
        ...map,
        'url': url,
        'urlArchivo': url,
        'descripcion': finalDesc,
        'usuarioNombre': finalAutor,
        'autor': finalAutor,
        'fechaCarga': finalFecha,
        'fechaCreacion': finalFecha,
      });
    }

    // 1. Lista extra de endpoint específico (ej. GET /api/actividades/{id}/evidencias)
    if (extraEvidences != null) {
      for (final item in extraEvidences) {
        if (item is Map) {
          addNormalizedMap(item);
        }
      }
    }

    // 2. Propiedad actividad.evidencias
    final evs = actData['evidencias'];
    if (evs is List) {
      for (final item in evs) {
        if (item is Map) {
          addNormalizedMap(item);
        } else if (item is String && item.trim().isNotEmpty) {
          addNormalizedMap({'urlArchivo': item.trim()});
        }
      }
    }

    // 3. Propiedad actividad.urlsEvidencias (List<String>)
    final urlsEvs = actData['urlsEvidencias'];
    if (urlsEvs is List) {
      for (final u in urlsEvs) {
        if (u != null && u.toString().trim().isNotEmpty) {
          addNormalizedMap({'urlArchivo': u.toString().trim()});
        }
      }
    }

    // 4. Propiedades individuales urlEvidencia / urlArchivo / fotoEvidencia / imagenBase64
    final singleUrl = (actData['urlEvidencia'] ??
            actData['urlArchivo'] ??
            actData['fotoEvidencia'] ??
            '')
        .toString()
        .trim();
    if (singleUrl.isNotEmpty && singleUrl.toLowerCase() != 'null') {
      addNormalizedMap({'urlArchivo': singleUrl});
    }

    final singleB64 = (actData['imagenBase64'] ?? '').toString().trim();
    if (singleB64.isNotEmpty && singleB64.toLowerCase() != 'null') {
      addNormalizedMap({'archivoBase64': singleB64});
    }

    // 5. Respaldo local en el dispositivo (SharedPreferences)
    if (localBackup != null) {
      for (final item in localBackup) {
        if (item is Map) {
          addNormalizedMap(item);
        }
      }
    }

    // 6. Si la actividad ya figura como COMPLETADA en la BD pero fue completada sin fila en actividad_evidencias
    final String estStr =
        (actData['estado'] ?? actData['estadoActividad'] ?? _estado)
            .toString()
            .toLowerCase();
    final bool isComp =
        estStr.contains('complet') || estStr.contains('finaliz');
    if (result.isEmpty && isComp) {
      final fallbackProjUrl =
          (actData['projectImageUrl'] ?? widget.actividad['projectImageUrl'] ?? '')
              .toString()
              .trim();
      addNormalizedMap({
        'urlArchivo': fallbackProjUrl,
        'descripcion': actObs.isNotEmpty
            ? actObs
            : 'Actividad completada y verificada en campo.',
        'usuarioNombre': defaultAuthor,
        'autor': defaultAuthor,
        'fechaCarga': defaultDate,
        'fechaCreacion': defaultDate,
      });
    }

    return result;
  }

  Future<List<dynamic>> _loadLocalEvidencesBackup(dynamic actId) async {
    if (actId == null) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_activity_evidences_$actId');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveLocalEvidenceBackup(
    dynamic actId,
    Map<String, dynamic> evItem,
  ) async {
    if (actId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await _loadLocalEvidencesBackup(actId);
      current.insert(0, evItem);
      await prefs.setString(
        'local_activity_evidences_$actId',
        jsonEncode(current),
      );
    } catch (_) {}
  }

  Future<void> _fetchActivityEvidences() async {
    final actId = _actividadData['id'] ?? widget.actividad['id'];
    if (actId == null) return;

    if (_existingEvidences.isEmpty && mounted) {
      setState(() => _isLoadingEvidences = true);
    }

    try {
      final token = await AuthService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      Map<String, dynamic> mergedAct = Map<String, dynamic>.from(_actividadData);
      List<dynamic> extraEvs = [];

      // 1. Consultar GET /api/cronograma-actividades/{id}
      try {
        final actRes = await http
            .get(
              Uri.parse(
                '${ApiConfig.baseUrl}/api/cronograma-actividades/$actId',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20));

        if (actRes.statusCode == 200 && actRes.body.isNotEmpty) {
          final decoded = jsonDecode(actRes.body);
          if (decoded is Map<String, dynamic>) {
            mergedAct = {
              ...mergedAct,
              ...decoded,
              'responsableNombre': decoded['usuarioResponsableNombre'] ??
                  decoded['responsableNombre'] ??
                  mergedAct['responsableNombre'],
              'responsableId': decoded['usuarioResponsableId'] ??
                  decoded['responsableId'] ??
                  mergedAct['responsableId'],
            };
          }
        }
      } catch (_) {}

      // 2. Consultar también GET /api/actividades/{id}/evidencias o /api/cronograma-actividades/{id}/evidencias si existen
      for (final path in [
        '/api/cronograma-actividades/$actId/evidencias',
        '/api/actividades/$actId/evidencias',
      ]) {
        try {
          final evRes = await http
              .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: headers)
              .timeout(const Duration(seconds: 10));
          if (evRes.statusCode == 200 && evRes.body.isNotEmpty) {
            final decoded = jsonDecode(evRes.body);
            if (decoded is List && decoded.isNotEmpty) {
              extraEvs.addAll(decoded);
              break;
            } else if (decoded is Map && decoded['evidencias'] is List) {
              extraEvs.addAll(decoded['evidencias'] as List);
              break;
            }
          }
        } catch (_) {}
      }

      final localBackup = await _loadLocalEvidencesBackup(actId);
      final extracted = _extractAllEvidences(
        mergedAct,
        extraEvidences: extraEvs,
        localBackup: localBackup,
      );

      if (mounted) {
        setState(() {
          _actividadData = mergedAct;
          _estado = mergedAct['estado']?.toString() ??
              mergedAct['estadoActividad']?.toString() ??
              _estado;
          _existingEvidences = extracted;
          _isLoadingEvidences = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingEvidences = false);
      }
    }
  }

  Future<void> _checkPermissions() async {
    final userData = await AuthStorage.getUserData();
    final currentUserId = userData?['id'] ?? await AuthStorage.getUserId();
    final currentUserEmail = (userData?['correo'] ??
            userData?['email'] ??
            await AuthStorage.getEmail())
        ?.toString()
        .trim()
        .toLowerCase();

    final nombres =
        (userData?['nombres'] ?? userData?['nombre'] ?? '').toString().trim();
    final apellidos = (userData?['apellidos'] ?? '').toString().trim();
    final fullName = '$nombres $apellidos'.trim();

    final rawRole = (userData?['rol'] ??
            userData?['role'] ??
            userData?['rolNombre'] ??
            '')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll('ROLE_', '');
    final userRole = rawRole;

    final respId = _responsableId;
    final respEmail = (_actividadData['usuarioResponsableEmail'] ??
            _actividadData['responsableEmail'] ??
            widget.actividad['usuarioResponsableEmail'] ??
            widget.actividad['responsableEmail'])
        ?.toString()
        .trim()
        .toLowerCase();

    final bool isAssignedById = respId != null &&
        currentUserId != null &&
        respId.toString() == currentUserId.toString();
    final bool isAssignedByEmail = respId == null &&
        respEmail != null &&
        respEmail.isNotEmpty &&
        currentUserEmail != null &&
        respEmail == currentUserEmail;

    final bool puedeGestionar = isAssignedById ||
        isAssignedByEmail ||
        (userRole == 'ADMIN' || userRole == 'COORDINADOR');

    if (mounted) {
      setState(() {
        _puedeGestionar = puedeGestionar;
        if (fullName.isNotEmpty) {
          _currentUserName = fullName;
        }
      });
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadEvidence() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor captura o selecciona una fotografía primero.',
          ),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final nowIso = DateTime.now().toIso8601String();
    final authorName = _currentUserName ??
        (_responsableNombre != 'Sin asignar'
            ? _responsableNombre
            : 'Guardabosques');
    final desc = _descController.text.trim();
    final actId = _actividadData['id'] ?? widget.actividad['id'];

    try {
      final token = await AuthService.getToken();

      // 1. Endpoint principal de subida de evidencias (POST /api/cronograma-actividades/{id}/evidencias)
      final postUri = Uri.parse(
        '${ApiConfig.baseUrl}/api/cronograma-actividades/$actId/evidencias',
      );
      final postReq = http.MultipartRequest('POST', postUri);
      if (token != null && token.isNotEmpty) {
        postReq.headers['Authorization'] = 'Bearer $token';
      }
      if (desc.isNotEmpty) {
        postReq.fields['descripcion'] = desc;
      }
      postReq.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _selectedImage!.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedPost =
          await postReq.send().timeout(const Duration(seconds: 50));
      http.Response response = await http.Response.fromStream(streamedPost);

      // 2. Fallback a PATCH /api/cronograma-actividades/{id}/completar si POST no fue 2xx
      if (response.statusCode != 200 && response.statusCode != 201) {
        final patchUri = Uri.parse(
          '${ApiConfig.baseUrl}/api/cronograma-actividades/$actId/completar',
        );
        final patchReq = http.MultipartRequest('PATCH', patchUri);
        if (token != null && token.isNotEmpty) {
          patchReq.headers['Authorization'] = 'Bearer $token';
        }
        patchReq.fields['descripcionEvidencia'] = desc;
        patchReq.fields['observaciones'] = desc;
        patchReq.files.add(
          await http.MultipartFile.fromPath(
            'files',
            _selectedImage!.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
        final streamedPatch =
            await patchReq.send().timeout(const Duration(seconds: 50));
        response = await http.Response.fromStream(streamedPatch);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic>? createdEv;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            if (decoded.containsKey('urlArchivo') ||
                decoded.containsKey('fechaCarga')) {
              createdEv = {
                ...decoded,
                'url': decoded['urlArchivo'] ?? decoded['url'] ?? '',
                'descripcion': decoded['descripcion'] ??
                    (desc.isNotEmpty ? desc : 'Evidencia registrada en campo'),
                'usuarioNombre': decoded['usuarioNombre'] ?? authorName,
                'autor': decoded['usuarioNombre'] ?? authorName,
                'fechaCarga': decoded['fechaCarga'] ?? nowIso,
                'fechaCreacion': decoded['fechaCarga'] ?? nowIso,
              };
            }
          }
        } catch (_) {}

        final fallbackItem = createdEv ??
            {
              'url': '',
              'localPath': _selectedImage!.path,
              'descripcion':
                  desc.isNotEmpty ? desc : 'Nueva evidencia de campo',
              'fechaCarga': nowIso,
              'fechaCreacion': nowIso,
              'createdAt': nowIso,
              'usuarioNombre': authorName,
              'autor': authorName,
            };

        await _saveLocalEvidenceBackup(actId, fallbackItem);

        setState(() {
          _existingEvidences.insert(0, fallbackItem);
          _selectedImage = null;
          _descController.clear();
          _estado = 'Completada';
          _actividadData['estado'] = 'completada';
        });

        await _fetchActivityEvidences();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Evidencia guardada exitosamente!'),
            backgroundColor: Color(0xFF1E5E3A),
          ),
        );
      } else {
        final localItem = {
          'url': '',
          'localPath': _selectedImage!.path,
          'descripcion': desc.isNotEmpty ? desc : 'Evidencia registrada',
          'fechaCarga': nowIso,
          'fechaCreacion': nowIso,
          'createdAt': nowIso,
          'usuarioNombre': authorName,
          'autor': authorName,
        };
        await _saveLocalEvidenceBackup(actId, localItem);

        setState(() {
          _existingEvidences.insert(0, localItem);
          _selectedImage = null;
          _descController.clear();
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidencia guardada localmente.'),
            backgroundColor: Color(0xFF1E5E3A),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (_selectedImage != null) {
        final offlineItem = {
          'url': '',
          'localPath': _selectedImage!.path,
          'descripcion': desc.isNotEmpty ? desc : 'Evidencia fuera de línea',
          'fechaCarga': nowIso,
          'fechaCreacion': nowIso,
          'createdAt': nowIso,
          'usuarioNombre': authorName,
          'autor': authorName,
        };
        await _saveLocalEvidenceBackup(actId, offlineItem);

        setState(() {
          _existingEvidences.insert(0, offlineItem);
          _selectedImage = null;
          _descController.clear();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidencia guardada fuera de línea.'),
            backgroundColor: Color(0xFF1E5E3A),
          ),
        );
      }
    }
  }

  void _confirmDeleteEvidence(int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD32F2F),
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '¿Eliminar esta imagen?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esta acción no se puede deshacer y retirará la evidencia de la actividad.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final ev = _existingEvidences[index];
                        final evId = ev is Map ? ev['id'] : null;
                        setState(() {
                          _existingEvidences.removeAt(index);
                        });
                        if (evId != null) {
                          try {
                            final token = await AuthService.getToken();
                            await http.delete(
                              Uri.parse(
                                '${ApiConfig.baseUrl}/api/evidencias-actividad/$evId',
                              ),
                              headers: {
                                if (token != null && token.isNotEmpty)
                                  'Authorization': 'Bearer $token',
                              },
                            );
                          } catch (_) {}
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Evidencia eliminada.'),
                            backgroundColor: Color(0xFFD32F2F),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombreActividad = widget.actividad['nombre']?.toString() ??
        widget.actividad['titulo']?.toString() ??
        'Actividad de campo';
    final descActividad = widget.actividad['descripcion']?.toString() ??
        'Actividad planificada para el cronograma del proyecto ambiental.';
    final fechaInicio = widget.actividad['fechaInicio']?.toString() ?? '';
    final fechaFin = widget.actividad['fechaFin']?.toString() ?? '';
    final periodoStr = (fechaInicio.isNotEmpty && fechaFin.isNotEmpty)
        ? '$fechaInicio - $fechaFin'
        : 'Periodo de ejecución del proyecto';

    final isCompletada = _estado.toLowerCase().contains('complet') ||
        _estado.toLowerCase().contains('finaliz');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E5E3A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text(
          'Evidencias de actividad',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F3A22),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cabecera de la Actividad
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            nombreActividad,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCompletada
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCompletada ? 'Completada' : 'En desarrollo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCompletada
                                  ? const Color(0xFF1E5E3A)
                                  : const Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          periodoStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Color(0xFF1E5E3A),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Responsable: $_responsableNombre',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E5E3A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      descActividad,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Contenedor "Agregar evidencia" o Banner informativo de restricción
              if (_puedeGestionar)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: Color(0xFF1E5E3A),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Agregar evidencia fotográfica',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F3A22),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Dos botones estilizados para seleccionar foto
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickImage(ImageSource.camera),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFC8E6C9),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      color: Color(0xFF1E5E3A),
                                      size: 19,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Tomar foto',
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickImage(ImageSource.gallery),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.photo_library_outlined,
                                      color: Color(0xFF374151),
                                      size: 19,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Galería',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Previsualización de la foto seleccionada
                      if (_selectedImage != null) ...[
                        const SizedBox(height: 14),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                _selectedImage!,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () => setState(() => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Campo de descripción con contador
                      TextField(
                        controller: _descController,
                        maxLength: 200,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Describe esta evidencia (opcional)...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                          counterText: '${_descController.text.length}/200',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E5E3A),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Botón "Guardar evidencia"
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _uploadEvidence,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 20,
                                ),
                          label: Text(
                            _isSaving ? 'Guardando...' : 'Guardar evidencia',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E5E3A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFB45309),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Solo el responsable asignado ($_responsableNombre) puede registrar evidencias y completar esta actividad.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 22),

              // 3. Sección "Evidencias subidas (N)"
              Row(
                children: [
                  const Text(
                    'Evidencias subidas',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F3A22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_existingEvidences.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E5E3A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoadingEvidences && _existingEvidences.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1E5E3A),
                      ),
                    ),
                  ),
                )
              else if (_existingEvidences.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 40,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aún no hay evidencias registradas.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _existingEvidences.length,
                  itemBuilder: (context, index) {
                    final ev = _existingEvidences[index];
                    return _buildEvidenceItem(ev, index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearFechaHora(dynamic rawDate) {
    final String raw = (rawDate ?? '').toString().trim();
    DateTime dt;
    if (raw.isEmpty ||
        raw.toLowerCase() == 'reciente' ||
        raw.toLowerCase() == 'hoy' ||
        raw.toLowerCase() == 'null') {
      final fallbackRaw = (widget.actividad['updatedAt'] ??
              widget.actividad['fechaActualizacion'] ??
              widget.actividad['createdAt'] ??
              widget.actividad['fechaCreacion'] ??
              '')
          .toString()
          .trim();
      dt = DateTime.tryParse(fallbackRaw)?.toLocal() ?? DateTime.now();
    } else {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) {
        return raw;
      }
      dt = parsed.isUtc ? parsed.toLocal() : parsed;
    }

    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final String dia = dt.day.toString().padLeft(2, '0');
    final String mes = meses[dt.month - 1];
    final int anio = dt.year;

    final int hour24 = dt.hour;
    final String amPm = hour24 >= 12 ? 'PM' : 'AM';
    final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final String horaStr = hour12.toString().padLeft(2, '0');
    final String minStr = dt.minute.toString().padLeft(2, '0');

    return '$dia $mes $anio, $horaStr:$minStr $amPm';
  }

  Widget _buildEvidenceImage(
    dynamic ev, {
    BoxFit fit = BoxFit.cover,
    double iconSize = 32,
  }) {
    final String url = (ev['url'] ?? ev['urlArchivo'] ?? ev['archivoUrl'] ?? '')
        .toString()
        .trim();
    final String localPath = (ev['localPath'] ?? '').toString().trim();
    final String base64Str = (ev['archivoBase64'] ?? '').toString().trim();

    if (localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade200,
          child: Icon(Icons.broken_image, size: iconSize),
        ),
      );
    }

    if (url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (context, u) => Container(
          color: const Color(0xFFE8F5E9),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1E5E3A),
              ),
            ),
          ),
        ),
        errorWidget: (context, u, err) => Container(
          color: Colors.grey.shade200,
          child: Icon(Icons.broken_image, size: iconSize),
        ),
      );
    }

    if (base64Str.isNotEmpty) {
      try {
        final cleanBase64 = base64Str.contains(',')
            ? base64Str.split(',').last
            : base64Str;
        return Image.memory(
          base64Decode(cleanBase64),
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade200,
            child: Icon(Icons.broken_image, size: iconSize),
          ),
        );
      } catch (_) {}
    }

    return Container(
      color: const Color(0xFFE8F5E9),
      child: Icon(
        Icons.park_rounded,
        color: const Color(0xFF1E5E3A),
        size: iconSize,
      ),
    );
  }

  void _mostrarDetalleEvidencia(BuildContext context, dynamic ev) {
    final String desc = (ev['descripcion'] ??
            ev['descripcionEvidencia'] ??
            'Sin descripción detallada.')
        .toString()
        .trim();
    final String autorRaw =
        (ev['usuarioNombre'] ?? ev['autor'] ?? '').toString().trim();
    final String autor = (autorRaw.isNotEmpty &&
            autorRaw.toLowerCase() != 'guardabosques' &&
            autorRaw.toLowerCase() != 'null')
        ? autorRaw
        : (_responsableNombre.isNotEmpty
            ? _responsableNombre
            : 'Guardabosques');
    final String fechaFormateada = _formatearFechaHora(
      ev['fechaCarga'] ??
          ev['fechaCreacion'] ??
          ev['createdAt'] ??
          ev['fechaSubida'] ??
          ev['fecha'],
    );
    final String nombreActividad = widget.actividad['nombre']?.toString() ??
        widget.actividad['titulo']?.toString() ??
        'Actividad de campo';
    final bool isCompletada = _estado.toLowerCase().contains('complet') ||
        _estado.toLowerCase().contains('finaliz');
    final bool isEnProgreso = _estado.toLowerCase().contains('progreso') ||
        _estado.toLowerCase().contains('curso');
    final Color statusColor = isCompletada
        ? const Color(0xFF1E5E3A)
        : (isEnProgreso ? const Color(0xFF0284C7) : const Color(0xFFD97706));
    final String statusLabel = isCompletada
        ? 'COMPLETADA'
        : (isEnProgreso ? 'EN PROGRESO' : 'PENDIENTE');

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera del modal con Título, Estado y botón Cerrar (X)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              nombreActividad,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF4B5563),
                        ),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                ),

                // Fotografía completa con zoom mediante InteractiveViewer
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 240,
                    maxHeight: 380,
                  ),
                  color: const Color(0xFF0F172A),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Center(
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: _buildEvidenceImage(
                            ev,
                            fit: BoxFit.contain,
                            iconSize: 56,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pellizca para hacer zoom',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Descripción completa y metadatos (Responsable + Fecha/Hora)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DESCRIPCIÓN DE LA EVIDENCIA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E5E3A),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        desc.isNotEmpty
                            ? desc
                            : 'Evidencia registrada en campo.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 16,
                                  color: Color(0xFF1E5E3A),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Subido por: ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    autor,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 15,
                                  color: Color(0xFF1E5E3A),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Fecha y hora: ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    fechaFormateada,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEvidenceItem(dynamic ev, int index) {
    final String desc = (ev['descripcion'] ??
            ev['descripcionEvidencia'] ??
            'Evidencia registrada en campo')
        .toString();
    final String fechaFormateada = _formatearFechaHora(
      ev['fechaCarga'] ??
          ev['fechaCreacion'] ??
          ev['createdAt'] ??
          ev['fechaSubida'] ??
          ev['fecha'],
    );
    final String autorRaw =
        (ev['usuarioNombre'] ?? ev['autor'] ?? '').toString().trim();
    final String autor = (autorRaw.isNotEmpty &&
            autorRaw.toLowerCase() != 'guardabosques' &&
            autorRaw.toLowerCase() != 'null')
        ? autorRaw
        : (_responsableNombre.isNotEmpty
            ? _responsableNombre
            : 'Guardabosques');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _mostrarDetalleEvidencia(context, ev),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Miniatura
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: _buildEvidenceImage(ev, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),

                // Datos de la evidencia
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              autor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              fechaFormateada,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Menú de 3 puntos (solo si tiene permiso para gestionar la actividad)
                if (_puedeGestionar)
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    onPressed: () => _confirmDeleteEvidence(index),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
